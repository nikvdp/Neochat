-- open this and do `:luafile %` to reload neocursor during dev

-- Unload all modules under a specific namespace
function unload_namespace(namespace)
    for module_name, _ in pairs(package.loaded) do
        if module_name:find(namespace, 1, true) == 1 then
            package.loaded[module_name] = nil
        end
    end
end

unload_namespace("neocursor.")

-- reload it
package.loaded["neocursor"] = nil
require("neocursor") -- loads an updated version of module 'modname'
