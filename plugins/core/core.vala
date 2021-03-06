/*
 * foobot - core plugin
 *
 * Copyright (c) 2011, Christoph Mende <mende.christoph@gmail.com>
 * All rights reserved. Released under the 2-clause BSD license.
 */


using Foobot;

public class Core : Peas.ExtensionBase, Plugin {
	public void init()
	{
		register_command("\001VERSION\001", "ctcp_version");
                register_command("addhost");
                register_command("adduser", null, 100);
                register_command("alias", null, 5);
                register_command("chlvl", null, 100);
                register_command("getuserdata", null, 10);
                register_command("help");
                register_command("hi", null, 0);
                register_command("join", null, 10);
                register_command("load" , null, 10);
                register_command("merge", null, 100);
                register_command("raw", null, 1000);
                register_command("reboot", null, 100);
                register_command("reload" , null, 10);
                register_command("shutdown", null, 1000);
                register_command("sql", null, 1000);
                register_command("unalias", null, 5);
                register_command("unload" , null, 10);
                register_command("update", null, 1000);
                register_command("version");
                register_command("who");
                register_command("whoami", null, 0);
                register_command("whois");
	}

	public string? run (string method, string channel, User user, string[] args) throws GLib.Error {
		switch (method) {
			case "ctcp_version":
				return ctcp_version(channel);
			case "addhost":
				return addhost(channel, user, args);
			case "adduser":
				return adduser(channel, user, args);
			case "alias":
				return alias(channel, user, args);
			case "chlvl":
				return chlvl(channel, user, args);
			case "getuserdata":
				return getuserdata(channel, user, args);
			case "help":
				return help(channel, user, args);
			case "hi":
				return hi(channel, user, args);
			case "join":
				return join(channel, user, args);
			case "load":
				return load(channel, user, args);
			case "merge":
				return merge(channel, user, args);
			case "raw":
				return raw(channel, user, args);
			case "reboot":
				return reboot(channel, user);
			case "reload":
				return reload(channel, user, args);
			case "shutdown":
				return shutdown(channel, user);
			case "sql":
				return sql(channel, user, args);
			case "unalias":
				return unalias(channel, user, args);
			case "unload":
				return unload(channel, user, args);
			case "update":
				return update();
			case "version":
				return version(channel, user);
			case "who":
				return who(channel, user, args);
			case "whoami":
				return whoami(channel, user);
			case "whois":
				return whois(channel, user, args);
			default:
				return null;
		}
	}

	public string? ctcp_version(string channel)
	{
		irc.send(@"NOTICE $channel :\001VERSION foobot v$(Foobot.Settings.version)\001");
		return null;
	}

	public string addhost(string channel, User user, string[] args) throws SQLHeavy.Error
	{
		int usrid;
		string hostmask;

		if (args.length > 1) {
			var r = db.prepare("SELECT id FROM users WHERE username=:name");
			r[":name"] = args[0];
			usrid = r.execute().fetch_int();
			hostmask = args[1];
		} else {
			usrid = user.id;
			hostmask = args[0];
		}

		if (!hostmask.contains("@"))
			return "Invalid format, use addhost ident@host";

		var hostdata = hostmask.split("@");

		var r = db.prepare("INSERT INTO hosts VALUES(:id, :ident, :host)");
		r[":id"] = usrid;
		r[":ident"] = hostdata[0];
		r[":host"] = hostdata[1];
		r.execute();

		return "Added host";
	}

	public string? adduser(string channel, User user, string[] args) throws SQLHeavy.Error
	{
		if (args.length == 0)
			return null;

		var nick = args[0];
		var new_user = bot.get_userlist(nick);

		if (new_user == null)
			return "Unknown nick";

		var r = db.prepare("INSERT INTO users (username, ulvl) VALUES(:name, 1)");
		r[":name"] = nick;
		var id = r.execute_insert();

		r = db.prepare("INSERT INTO hosts VALUES(:id, :ident, :host)");
		r[":id"] = id;
		r[":ident"] = new_user.ident;
		r[":host"] = new_user.host;
		r.execute();

		irc.send("WHO " + new_user.nick);

		return @"Added user $id identified by $(new_user.ident)@$(new_user.host)";
	}

	public string alias(string channel, User user, string[] args)
	{
		var alias = args[0].down();
		var function = args[1].down();
		var alias_args = args[2:args.length];
		bot.register_alias(alias, function, alias_args);
		return "Okay";
	}

	public string? chlvl(string channel, User user, string[] args)
	{
		// TODO
		return null;
	}

	public string? getuserdata(string channel, User user, string[] args)
	{
		// TODO
		return null;
	}

	public string? help(string channel, User user, string[] args)
	{
		// TODO
		return null;
	}

	public string? hi(string channel, User user, string[] args) throws SQLHeavy.Error
	{
		var users = db.execute("SELECT COUNT(id) FROM users").fetch_int();
		if (users > 0)
			return null;

		var r = db.prepare("INSERT INTO users (username, ulvl) VALUES(:name, 1000);");
		r[":name"] = user.nick;
		var id = r.execute_insert();

		r = db.prepare("INSERT INTO hosts VALUES(:id, :ident, :host);");
		r[":id"] = id;
		r[":ident"] = user.ident;
		r[":host"] = user.host;
		r.execute();

		irc.send(@"WHO $(user.nick)");
		return @"Hi, you are now my owner, recognized by $(user.ident)@$(user.host).";
	}

	public string? join(string channel, User user, string[] args)
	{
		return_if_fail(args.length > 0);

		if (args.length > 1)
			irc.join(args[0], args[1]);
		else
			irc.join(args[0]);
		return null;
	}

	public string load(string channel, User user, string[] args)
	{
		var plugin = args[0];

		if (Plugins.load(plugin))
			return @"$plugin loaded";
		else
			return @"failed to load $plugin";
	}

	public string merge(string channel, User user, string[] args) throws SQLHeavy.Error
	{
		if (args.length < 2)
			return "Usage: merge username nickname";

		var tmpusr = bot.get_userlist(args[1]);
		if (tmpusr == null)
			return "Unknown nick";

		var r = db.prepare("SELECT id FROM users WHERE username LIKE :name");
		r[":name"] = args[0];
		var usrid = r.execute().fetch_int();
		if (usrid == 0)
			return "Unknown user";

		r = db.prepare("INSERT INTO hosts VALUES(:id, :ident, :host)");
		r[":id"] = usrid;
		r[":ident"] = tmpusr.ident;
		r[":host"] = tmpusr.host;
		r.execute();
		return "Users merged";
	}

	public string? raw(string channel, User user, string[] args)
	{
		var msg = string.joinv(" ", args);
		irc.send(msg);
		return null;
	}

	public string? reboot(string channel, User user)
	{
		// TODO
		return null;
	}

	public string reload(string channel, User user, string[] args)
	{
		var plugin = args[0];

		if (Plugins.unload(plugin) && Plugins.load(plugin))
			return @"$plugin reloaded";
		else
			return @"failed to reload $plugin";
	}

	public string? shutdown(string channel, User user)
	{
		bot.shutdown(@"Shutting down as requesetd by $(user.name)");
		return null;
	}

	public string? sql(string channel, User user, string[] args)
	{
		// TODO
		return null;
	}

	public string? unalias(string channel, User user, string[] args)
	{
		// TODO
		return null;
	}

	public string unload(string channel, User user, string[] args)
	{
		var plugin = args[0];

		if (plugin.down() == "core")
			return "not going to unload core";

		if (Plugins.unload(plugin))
			return @"$plugin unloaded";
		else
			return @"failed to unload $plugin";
	}

	public string? update()
	{
		// TODO
		return null;
	}

	public string? version(string channel, User user)
	{
		// TODO
		return null;
	}

	public string who(string channel, User user, string[] args)
	{
		return_if_fail(args.length > 0);

		var nick = args[0];
		irc.send(@"WHO $nick");
		return "Okay";
	}

	public string whoami(string channel, User user)
	{
		string msg;
		if (user.id > 0) {
			msg = "You are ";
			if (user.title != null)
				msg += user.title + " ";
			msg += user.name + ", level " + user.level.to_string();
		} else {
			msg = "You are unknown";
		}
		return msg;
	}

	public string whois(string channel, User user, string[] args)
	{
		return_if_fail(args.length > 0);

		var nick = args[0];
		var tmpuser = bot.get_userlist(nick);
		string msg;
		if (tmpuser != null && tmpuser.id > 0) {
			msg = tmpuser.nick + " is ";
			if (tmpuser.title != null)
				msg += tmpuser.title + " ";
			msg += tmpuser.name + ", level " + tmpuser.level.to_string();
		} else {
			msg = nick + " is unknown";
		}
		return msg;
	}
}

[ModuleInit]
public void peas_register_types(GLib.TypeModule module)
{
	var objmodule = module as Peas.ObjectModule;
	objmodule.register_extension_type(typeof (Plugin), typeof (Core));
}
