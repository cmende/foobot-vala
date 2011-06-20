/*
 * Copyright (C) 2011  Christoph Mende
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


using GLib;
using Config;

class PluginLoader : Object
{
	public string path { get; private set; }

	private Type type;
	private Module module;

	private delegate Type RegisterPluginFunction();

	public PluginLoader(string name)
	{
		assert (Module.supported());
		path = Module.build_path(PLUGINDIR, name);
	}

	public Plugin? load()
	{
		stdout.printf("Loading plugin: %s\n", path);

		module = Module.open(path, ModuleFlags.BIND_LAZY);
		if (module == null) {
			stderr.printf("Failed to load module: %s\n", Module.error());
			return null;
		}

		stdout.printf("Loaded module: %s\n", module.name());

		void* function;
		module.symbol("register_plugin", out function);
		RegisterPluginFunction register_plugin = (RegisterPluginFunction) function;
		type = register_plugin();

		var plug = (Plugin) Object.new(type);

		return plug;
	}
}

public class Plugins : Object
{
	private static Plugin[] loaded;

	public static bool load(string name)
	{
		var registrar = new PluginLoader(name);
		var plug = registrar.load();
		if (plug == null)
			return false;

		plug.init();
		loaded += plug;
		return true;
	}

	public static void run_joined(string channel, string nick)
	{
		print(@"signal: $nick joined $channel\n");
	}

	public static void run_said(string channel, string nick, string text)
	{
		print(@"signal: $nick said '$text' in $channel\n");
	}

	public static void run_command(string channel, string nick, string cmd, string[] args)
	{
		print(@"signal: $nick executed $cmd in $channel\n");
	}
}
