/*
 * foobot - IRC bot
 *
 * Copyright (c) 2011, Christoph Mende <mende.christoph@gmail.com>
 * All rights reserved. Released under the 2-clause BSD license.
 */


using GLib;
using Gda;

namespace Foobot
{
	/**
	 * Database management
	 */
	public class Foodb : Object
	{
		private Connection db;

		internal Foodb()
		{
			Gda.init();

			try {
				db = Connection.open_from_string("SQLite", @"DB_DIR=.;DB_NAME=foobot-$(Settings.network)", null, ConnectionOptions.NONE);
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
			}

			initialize();
		}

		private void initialize()
		{
			try {
				db.begin_transaction("init", TransactionIsolation.UNKNOWN);
				exec("CREATE TABLE IF NOT EXISTS users (id integer primary key, username varchar(25) unique, title varchar(25), ulvl integer, userdata varchar(150))");
				exec("CREATE TABLE IF NOT EXISTS hosts (usrid integer, ident varchar(10), host varchar(50))");
				exec("CREATE TABLE IF NOT EXISTS timed_events (id integer primary key, plugin varchar(25), function varchar(25), time int(11), args varchar(255))");
				exec("CREATE TABLE IF NOT EXISTS aliases (id integer primary key, alias varchar(50), function varchar(50), args varchar(250))");
				db.commit_transaction("init");
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
			}
		}

		/**
		 * Execute a non-select statement
		 * @param sql query string
		 * @return number of rows affected or -1 on error
		 */
		public int exec(string sql)
		{
			try {
				return db.execute_non_select_command(sql);
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
				return -1;
			}
		}

		/**
		 * Execute a non-select statement
		 * @param b Gda.SqlBuilder object containing the query
		 * @return number of rows affected or -1 on error
		 */
		public int exec_from_builder(Gda.SqlBuilder b)
		{
			try {
				return exec_from_stmt(b.get_statement());
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
				return -1;
			}
		}

		/**
		 * Execute a non-select statement
		 * @param stmt Gda.Statement containing the query
		 * @return number of rows affected or -1 on error
		 */
		public int exec_from_stmt(Gda.Statement stmt)
		{
			try {
				return exec(stmt.to_sql_extended(db, null, StatementSqlFlag.PARAMS_SHORT, null));
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
				return -1;
			}
		}

		/**
		 * Execute a select statement
		 * @param sql query string
		 * @return Gda.DataModel containing the result or null on error
		 */
		public DataModel? select(string sql)
		{
			try {
				return db.execute_select_command(sql);
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
				return null;
			}
		}

		/**
		 * Execute a select statement
		 * @param b Gda.SqlBuilder object containing the query
		 * @return Gda.DataModel containing the result or null on error
		 */
		public DataModel? select_from_builder(Gda.SqlBuilder b)
		{
			try {
				return select_from_stmt(b.get_statement());
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
				return null;
			}
		}

		/**
		 * Execute a select statement
		 * @param stmt Gda.Statement containing the query
		 * @return Gda.DataModel containing the result or null on error
		 */
		public DataModel? select_from_stmt(Gda.Statement stmt)
		{
			try {
				return select(stmt.to_sql_extended(db, null, StatementSqlFlag.PARAMS_SHORT, null));
			} catch (Error e) {
				stderr.printf("%s\n", e.message);
				return null;
			}
		}

		/**
		 * Get the id of the last inserted row
		 * @param table table to query
		 * @return insert id
		 */
		public int last_insert_id(string table)
		{
			var b = new SqlBuilder(SqlStatementType.SELECT);
			b.select_add_target(table, null);
			b.add_field_value_id(b.add_id("_ROWID_"), 0);
			b.select_order_by(b.add_id("_ROWID_"), false, null);
			b.select_set_limit(b.add_expr(null, typeof(int), 1), 0);
			var result = select_from_builder(b);
			var value = result.get_value_at(0, 0);
			return value.get_int();
		}
	}
}
