AC_INIT([foobot], [0.1.0], [mende.christoph@gmail.com], [foobot])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([dist-bzip2 foreign subdir-objects])
AM_MAINTAINER_MODE

AC_PROG_CC
LT_PREREQ([2.2.6])
LT_INIT([disable-static])

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

plugindir="${libdir}/foobot"
AC_SUBST(plugindir)

GLIB_REQUIRED=2.26

PKG_PROG_PKG_CONFIG([0.24])
PKG_CHECK_MODULES(FOOBOT, glib-2.0 >= $GLIB_REQUIRED
		  gmodule-2.0 >= $GLIB_REQUIRED
		  gobject-2.0 >= $GLIB_REQUIRED
		  gio-2.0 >= $GLIB_REQUIRED
		  libpeas-1.0
		  sqlheavy-0.1)

AC_CONFIG_FILES([Makefile
		 plugins/Makefile
		 plugins/bofh/Makefile
		 plugins/core/Makefile
		 plugins/demo/Makefile
		 plugins/eightball/Makefile
		 plugins/qalc/Makefile
		 plugins/quotes/Makefile
		 plugins/slogans/Makefile
		 plugins/snack/Makefile
		 plugins/tvguide/Makefile
		 ])
AC_OUTPUT
