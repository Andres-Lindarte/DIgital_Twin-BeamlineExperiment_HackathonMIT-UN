/**
  simple.c - Simple example of a C extension module for Lua.
  The purpose is to call C code from Lua.
 
  This file must be compiled to simple.dll.  simple.dll must then be
  placed in a folder locatable via the Lua package.cpath variable, such as
  "c:\Program Files\SIMION-8.1\lua\lib" (64-bit or 32-bit) or
  "c:\Program Files\SIMION-8.1\x32\lua\lib" (32-bit).
 
  You can test it in SIMION by entering these two lines in the SIMION
  command bar:
 
    require "simple"
    = simple.add(3,4)
 
  D.Manura, 2007-02, 2011-10
  (c) 2006-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0/8.1)
*/

/* Include the Lua headers for C.
   These are typically located in "c:\Program Files\SIMION-8.1\lib\lua".
   You'll need to tell your C compiler to search for include headers files
   in that directory. */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#define DLLEXPORT __declspec(dllexport)

/* This is a C function exposed to Lua.
   Lua requires such functions to have this prototype. */
static int add(lua_State *L) {
    /* Check that the first two parameters passed to the function
       are numbers and obtain them. */
    double x = luaL_checknumber(L, 1);
    double y = luaL_checknumber(L, 2);

    /* Do some computation in C. */
    double result = x + y;

    /* Push the return value on the Lua stack. */
    lua_pushnumber(L, result);
    return 1; /* number of return values */
}

/* List of C functions to register in Lua.
   This must be terminated with {NULL,NULL}. */
struct luaL_reg simplelib[] = {
    {"add", add},
    {NULL, NULL}
};

/* When Lua loads this module, it calls this function to
   do its initialization.
   It must have the name "luaopen_x" where "x" is the name of
   the module loading by require "x" in Lua.
   The DLLEXPORT exports this function in the DLL
   so that its visible to outsiders (i.e. Lua).
 */
DLLEXPORT int luaopen_simple(lua_State *L) {
    /* This sets up the module and registers the C functions. */
    luaL_newmetatable(L, "my simple module");
    luaL_openlib(L, "simple", simplelib, 0);
    return 1;
}

