local mock_loop = require 'spec.mock_loop'

describe("textDocument/completion", function()
	it("returns nothing with no symbols", function()
		mock_loop(function(rpc)
			local text =  "\n"
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 0, character = 0}
			}, function(out)
				assert.same({
					isIncomplete = false,
					items = {}
				}, out)
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)

	it("returns local variables", function()
		mock_loop(function(rpc)
			local text =  "local mySymbol\nreturn m"
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 1, character = 8}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.same({
					isIncomplete = false,
					items = {{label = "mySymbol", kind = 6}}
				}, out)
				callme = true
			end)
			assert.truthy(callme)

			callme = nil
			text = "local symbolA, symbolB\n return s"
			rpc.notify("textDocument/didChange", {
				textDocument = {uri = doc.uri},
				contentChanges = {{text = text}}
			})
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 1, character = 9}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a.label < b.label
				end)
				assert.same({
					isIncomplete = false,
					items = {{label = "symbolA", kind = 6},{label="symbolB", kind = 6}}
				}, out)
				callme = true
			end)
			assert.truthy(callme)

			callme = nil
			text = "local symbolC \nlocal s\n local symbolD"
			rpc.notify("textDocument/didChange", {
				textDocument = {uri = doc.uri},
				contentChanges = {{text = text}}
			})
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 1, character = 7}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.same({
					isIncomplete = false,
					items = {{label = "symbolC", kind = 6}}
				}, out)
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)

	it("returns table fields", function()
		mock_loop(function(rpc)
			local text =  [[
local tbl={}
tbl.string='a'
tbl.number=42
return t
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 3, character = 8}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = '<table>',
					label  = 'tbl',
					kind = 6,
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)

			callme = nil
			text = text:gsub("\n$","bl.st\n")
			rpc.notify("textDocument/didChange", {
				textDocument = {uri = doc.uri},
				contentChanges = {{text = text}}
			})
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 3, character = 12}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a.label < b.label
				end)
				assert.same({
					isIncomplete = false,
					items = {{detail = '"a"', label = "string", kind = 6}}
				}, out)
				callme = true
			end)
			assert.truthy(callme)
			callme = nil
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 3, character = 12}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a.label < b.label
				end)
				assert.same({
					isIncomplete = false,
					items = {{detail = '"a"', label = "string", kind = 6}}
				}, out)
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)

	it("resolves modules", function()
		mock_loop(function(rpc)
			local text =  [[
local tbl=require'mymod'
print(t)
return tbl.a
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 1, character = 7}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = 'M<mymod>',
					label  = 'tbl',
					kind = 9,
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)

	it("resolves strings", function()
		mock_loop(function(rpc)
			local text =  [[
string = {test_example = true}
local mystr = ""
return mystr.t
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 2, character = 13}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = 'True',
					label  = 'test_example',
					kind = 6,
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end, {"_test"})
	end)

	it("resolves calls to setmetatable", function()
		mock_loop(function(rpc)
			local text =  [[
local mytbl = setmetatable({jeff=1}, {})
return mytbl.j
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 1, character = 13}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = '1',
					label  = 'jeff',
					kind = 6,
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end, {"_test"})
	end)

	it("does not resolve invalid/incorrect keys", function()
		mock_loop(function(rpc)
			local text =  [[
-- comment
return nonexistent.a
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 0, character = 0}
			}, function(out)
				assert.equal(0, #out.items)
				callme = true
			end)
			assert.truthy(callme)

			callme = false
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 1, character = 19}
			}, function(out)
				assert.equal(0, #out.items)
				callme = true
			end)
			assert.truthy(callme)
		end, {"_test"})
	end)

	it("can resolve varargs", function()
		mock_loop(function(rpc)
			local text =  [[
function my_fun(...)
	return { ... }
end
return my_f
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 3, character = 11}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = '<function>',
					label  = 'my_fun(...) ',
					insertText = 'my_fun',
					kind = 3,
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)


	it("can resolve simple function returns", function()
		mock_loop(function(rpc)
			local text =  [[
function my_fun()
	return { field = "a" }
end
local mytbl = my_fun()
return mytbl.f
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 4, character = 13}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = '"a"',
					label  = 'field',
					kind = 6,
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)

	pending("can handle function return modification", function()
		mock_loop(function(rpc)
			local text =  [[
function my_fun()
	return { field = "a" }
end
local mytbl = my_fun() mytbl.jeff = "b"
return mytbl.j
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 4, character = 14}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a.label < b.label
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = '"b"',
					label  = 'jeff'
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)

	pending("can resolve inline function returns", function()
		mock_loop(function(rpc)
			local text =  [[
function my_fun()
	return { field = "a" }
end
return my_fun().f
]]
			local doc = {
				uri = "file:///tmp/fake.lua"
			}
			rpc.notify("textDocument/didOpen", {
				textDocument = {uri = doc.uri, text = text}
			})
			local callme
			rpc.request("textDocument/completion", {
				textDocument = doc,
				position = {line = 4, character = 13}
			}, function(out)
				table.sort(out.items, function(a, b)
					return a < b
				end)
				assert.equal(1, #out.items)
				assert.same({
					detail = 'M<mymod>',
					label  = 'tbl'
				}, out.items[1])
				callme = true
			end)
			assert.truthy(callme)
		end)
	end)
end)
