-- open this and do `:luafile %` to reload the plugin during dev
local plugin_namespace = "neochat"

-- Unload all modules under the given namespace
function unload_namespace(namespace)
    for module_name, _ in pairs(package.loaded) do
        if module_name:find(namespace, 1, true) == 1 then
            package.loaded[module_name] = nil
        end
    end
end

unload_namespace(string.format("%s.", plugin_namespace))

-- reload it
package.loaded[plugin_namespace] = nil
require(plugin_namespace) -- loads an updated version of module 'modname'
