local logger = require "tacky.logger"

local State = {}
State.__index = State

local ctr = 0
function State.create(variables, states, scope)
	if not variables then error("variables cannot be nil", 2) end
	if not states then error("states cannot be nil", 2) end
	if not scope then error("scope cannot be nil", 2) end

	local state = setmetatable({
		--- The scope this top level definition lives under
		scope = scope,

		--- Variable to state mapping
		states = states,

		-- Variable ID to variable mapping
		variables = variables,

		--- List of all required variables
		required = {},
		requiredSet = {},

		--- The current stage we are in.
		-- Transitions from parsed -> built -> executed
		stage = "parsed",

		--- The variable this node is defined as
		var = nil,

		--- The final node for this entry. This is set when building
		-- has finished.
		node = nil,

		--- The actual value of this node. This is set when this function
		-- is executed.
		value = nil,
	}, State)

	return state
end

function State:require(var)
	if self.stage ~= "parsed" then
		error("Cannot add requirement when in stage " .. self.stage, 2)
	end

	if var.scope.isRoot then
		local state = assert(self.states[var], "Variable's State is nil: it probably hasn't finished parsing: " .. var.name)
		if not self.requiredSet[state] then
			-- Ensures they are emitted in the same order
			self.requiredSet[state] = true
			self.required[#self.required + 1] = state
		end
		return state
	end
end

function State:define(var)
	if self.stage ~= "parsed" then
		error("Cannot add definition when in stage " .. self.stage, 2)
	end

	if var.scope ~= self.scope then return end

	if self.var then
		error("Cannot redeclare variable, already have: " .. self.var.name, 2)
	end

	self.var = var
	self.states[var] = self

	-- Also store this as the hash.
	self.variables[tostring(var)] = var
end

function State:built(node)
	if not node then error("node cannot be nil", 2) end

	if self.stage ~= "parsed" then
		error("Cannot transition from " .. self.stage .. " to built", 2)
	end

	self.stage = "built"
	self.node = node

	if node.defVar ~= self.var then
		logger.printError("Variables are different for " .. self.var.name)
		print("Original variable defined at")
		logger.putTrace(self.var.node)

		print("New variable defined at")
		logger.putTrace(node)

		error("An error occured", 0)
	end
end

function State:executed(value)
	if self.stage ~= "built" then
		error("Cannot transition from " .. self.stage .. " to executed", 2)
	end

	self.stage = "executed"
	self.value = value
end

function State:get()
	if self.stage == "executed" then
		return self.value
	end

	local required, requiredList = {}, {}

	--- We walk the tree of all nodes, marking them as required
	-- but also detecting loops in definitions.
	-- This could probably be optimised so we don't walk the same tree multiple
	-- times.
	local function visit(state, stack, stackHash)
		local idx = stackHash[state]
		if idx then
			if state.var.tag ~= "macro" then
				return
			end

			local states = {}
			for i = idx, #stack do
				states[#states + 1] = stack[i].var.name
			end
			states[#states + 1] = state.var.name

			error("Loop in macro: " .. table.concat(states, " -> "))
		end

		idx = #stack + 1

		stack[idx] = state
		stackHash[state] = idx

		if not required[state] then
			-- Ensures they are emitted in the same order, not the correct one though.
			required[state] = true
			requiredList[#requiredList + 1] = state
		end

		local visited = {}

		-- Look for loops the first time round
		for _, inner in pairs(state.required) do
			visited[inner] = true
			visit(inner, stack, stackHash)
		end

		if state.stage ~= "built" and state.stage ~= "executed" then
			coroutine.yield({
				tag = "build",
				state = state,
			})
		end

		-- Add remaining dependencies now
		for _, inner in pairs(state.required) do
			if not visited[inner] then
				visit(inner, stack, stackHash)
			end
		end

		stack[idx] = nil
		stackHash[state] = nil
	end

	visit(self, {}, {})

	coroutine.yield({
		tag    = "execute",
		states = requiredList,
	})

	return self.value
end

return State
