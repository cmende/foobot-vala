/*
 * foobot - IRC bot
 *
 * Copyright (c) 2011, Christoph Mende <mende.christoph@gmail.com>
 * All rights reserved. Released under the 2-clause BSD license.
 */


using GLib;

namespace Foobot
{
	struct Alias {
		string function;
		string[]? args;
		int64 id;
	}

	/**
	 * Internal bot data
	 */
	public class Bot : Object
	{
		private HashTable<string,User> userlist;
		private HashTable<string,Alias?> aliases;
		private SocketConnection conn;

		internal Bot()
		{
			userlist = new HashTable<string,User>(str_hash, str_equal);
			aliases = new HashTable<string,Alias?>(str_hash, str_equal);
			irc = new IRC();
		}

		internal bool irc_connect()
		{
			log("Connecting");

			try {
				// Resolve
				var resolver = Resolver.get_default();
				var addresses =	resolver.lookup_by_name(Settings.server);
				var address = addresses.nth_data(0);

				// Connect
				var client = new SocketClient();
				client.tls = Settings.ssl;
				client.tls_validation_flags = 0;

				conn = client.connect (new
						InetSocketAddress(address,
							Settings.port));
				istream = new DataInputStream(conn.input_stream);
				ostream = new
					DataOutputStream(conn.output_stream);

				// Send user/nick
				irc.send(@"USER $(Settings.username) +i * "
						+ @":$(Settings.realname)");
				irc.send(@"NICK $(Settings.nick)");

				// Read response
				for (;;) {
					var line = istream.read_line(null).strip();
					if (@"001 $(Settings.nick) :" in line) {
						log("Connected");
						return true;
					}
				}
			} catch (Error e) {
				report_error(e);
			}

			return false;
		}

		internal void irc_post_connect()
		{
			// TODO auth
			if (Settings.debug_mode && Settings.debug_channel != null) {
				var info = Settings.debug_channel.split(" ");
				if (info[1] == null)
					irc.join(info[0]);
				else
					irc.join(info[0], info[1]);
			}

			foreach (var channel in Settings.channels) {
				var info = channel.split(" ");
				if (info[1] == null)
					irc.join(info[0]);
				else
					irc.join(info[0], info[1]);
			}
		}

		internal void log(string msg)
		{
			print("log: %s\n", msg);
		}

		internal async void wait()
		{
			try {
				var line = yield istream.read_line_async();
				parse(line);
			} catch (Error e) {
				warning(e.message);
			}
			wait();
		}

		internal void parse(string line)
		{
			MatchInfo match_info;

			if (line.has_prefix("ERROR :")) {
				warning(line);
				return;
			}

			if (line.has_prefix("PING :"))
				irc.send(@"PONG :$(line[6:line.length])");

			// Update userlist on JOIN, NICK and WHO events
			try {
				if (new Regex(@"^:[^ ]+ (?<cmd>352) $(Settings.nick) [^ ]+ (?<ident>[^ ]+) (?<host>[^ ]+) [^ ]+ (?<nick>[^ ]+) [^ ]+ :").match(line, 0, out match_info) ||
						new Regex("^:(?<nick>.+)!(?<ident>.+)@(?<host>.+) (?<cmd>JOIN) :(?<channel>[^ \r\n]+)").match(line, 0, out match_info) ||
						new Regex("^:(?<oldnick>[^ ]+)!(?<ident>[^ ]+)@(?<host>[^ ]+) (?<cmd>NICK) :(?<nick>[^ \r\n]+)").match(line, 0, out match_info)) {
					var nick = match_info.fetch_named("nick");
					var ident = match_info.fetch_named("ident");
					var host = match_info.fetch_named("host");
					var user = new User(nick, ident, host);

					userlist.insert(nick, user);

					if (match_info.fetch_named("cmd") == "NICK") {
						userlist.remove(match_info.fetch_named("oldnick"));
					} else if (match_info.fetch_named("cmd") == "JOIN") {
						irc.joined(match_info.fetch_named("channel"), user);
					}
				}
			} catch (Error e) {
				warning(e.message);
			}

			// Parse PRIVMSG
			try {
				if (new Regex(":(?<nick>[^ ]+)!(?<ident>[^ ]+)@(?<host>[^ ]+) PRIVMSG (?<target>[^ ]+) :(?<text>.+)").match(line, 0, out match_info)) {
					var nick = match_info.fetch_named("nick");
					var user = userlist.lookup(nick);
					var target = match_info.fetch_named("target");
					var text = match_info.fetch_named("text");
					string channel;

					// Set channel to the origin's nick if the
					// PRIVMSG was sent directly to the bot
					if (target == Settings.nick)
						channel = nick;
					else
						channel = target;

					irc.said(channel, user, text);

					if (text[0:Settings.command_char.length] == Settings.command_char ||
							channel == nick ||
							(text.length > Settings.nick.length + 2 &&
							 text[0:(Settings.nick.length + 2)] == @"$(Settings.nick): ")) {
						if (text.ascii_ncasecmp(@"$(Settings.nick): ", Settings.nick.length + 2) == 0)
							text = text.substring(Settings.nick.length + 2);

						if (text.ascii_ncasecmp(Settings.command_char, Settings.command_char.length) == 0)
							text = text.substring(Settings.command_char.length);

						if (text.length > 0) {
							var args = text.split(" ");
							var cmd = args[0];
							args = args[1:args.length];
							Plugins.run_command(channel, user, cmd, args);
							var alias = aliases.lookup(cmd);
							if (alias != null) {
								var merged_args = string.joinv(" ", alias.args) + text;
								var alias_args = merged_args.split(" ");
								Plugins.run_command(channel, user, alias.function, alias_args);
							}
							// TODO forward query
						}
					}
				}
			} catch (Error e) {
				warning(e.message);
			}
		}

		/**
		 * Fetch an entry from the internal userlist
		 * @param nick name of the entry
		 * @return a #User object or null if there is no such entry
		 */
		public User? get_userlist(string nick)
		{
			return userlist.lookup(nick);
		}

		/**
		 * Quit the bot, disconnecting from IRC
		 * @param msg quit message on IRC
		 */
		public void shutdown(string msg)
		{
			irc.send(@"QUIT :$msg");
			loop.quit();
		}

		internal void report_error(Error e)
		{
			string msg = "Plugin error: " + e.message;

			if (Settings.debug_channel != null)
				irc.say(Settings.debug_channel, msg);

			log(msg);
		}

		/**
		 * Register a command alias
		 */
		public void register_alias(string alias, string _function, string[]? args = null, int64 id = 0)
		{
			var function = _function.down();

			if (id == 0) {
				try {
					var r = db.prepare("INSERT INTO aliases (alias, function, args) VALUES(:alias, :function, :args)");
					r[":alias"] = alias;
					r[":function"] = function;
					// TODO: serialize args and insert
					r[":args"] = "";
					id = r.execute_insert();
				} catch (Error e) {
					report_error(e);
				}
			}

			var alias_data = Alias();
			alias_data.function = function;
			alias_data.args = args;
			alias_data.id = id;
			aliases.insert(alias, alias_data);
		}
	}
}
