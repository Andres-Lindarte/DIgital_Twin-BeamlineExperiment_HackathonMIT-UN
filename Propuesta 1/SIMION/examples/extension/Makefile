# Makefile for various compilers.
# Note: 32-bit and 64-bit simion.exe's must use 32-bit and 64-bit extension DLL's respectively.

# Generic, 32-bit, and 64-bit SIMION program paths (default assumes a 64-bit OS).
SIMIONPATH=c:/Program Files/SIMION-8.1
SIMIONPATH64=$(SIMIONPATH)
SIMIONPATH32=$(SIMIONPATH)/x32

# Enable one of these (C or C++ compile):
SIMPLE=simple.c
#SIMPLE=simple.cpp

# Microsoft C/C++ (Visual Studio 2008/2010 or Windows SDK) compilations.

# Microsoft C/C++, 32-bit.  Must be run from the 32-bit compiler.
simple-msvc32 :
	cl /O2 "/I$(SIMIONPATH)/lib/cpp" $(SIMPLE) /link /dll /out:simple.dll "$(SIMIONPATH32)/lib/cpp/lua51.lib"
# Microsoft C/C++, 64-bit.  Must be run from the 64-bit compiler.
simple-msvc64 :
	cl /O2 "/I$(SIMIONPATH)/lib/cpp" $(SIMPLE) /link /dll /out:simple.dll "$(SIMIONPATH64)/lib/cpp/lua51.lib"
# Regenerating the lua51.lib file (32- or 64-bit) yourself is optional.
# If done, adjust lua51.lib paths above to point to it.
lualib-msvc32 :
	lib /machine:X86 "/def:$(SIMIONPATH)/lib/cpp/lua51.def"
lualib-msvc64 :
	lib /machine:X64 "/def:$(SIMIONPATH)/lib/cpp/lua51.def"

# MinGW (including Cygwin) GCC C/C++ compilations.

# MinGW (including Cygwin), 32-bit
simple-mingw32 :
	i686-w64-mingw32-gcc   -O2 -shared "-I$(SIMIONPATH)/lib/cpp" $(SIMPLE) "$(SIMIONPATH32)/lib/lua51.dll" -o simple.dll
# MinGW (including Cygwin), 64-bit
simple-mingw64 :
	x86_64-w64-mingw32-gcc -O2 -shared "-I$(SIMIONPATH)/lib/cpp" $(SIMPLE) "$(SIMIONPATH64)/lib/lua51.dll" -o simple.dll

# MinGW or Cygwin default compile.  Could be 32-bit or 64-bit depending on your system.
#   On Cygwin, this generates a DLL linking to Cygwin DLLs, which is probably not what you want.
simple-gcc32 :
	gcc -O2 -shared -I../../lib/cpp $(SIMPLE) "$(SIMIONPATH32)/lib/lua51.dll" -o simple.dll
simple-gcc64 :
	gcc -O2 -shared -I../../lib/cpp $(SIMPLE) "$(SIMIONPATH64)/lib/lua51.dll" -o simple.dll


# Footnotes:
# On Microsoft C/C++, if you receive an error "LNK2019: unresolved external symbol _lua_pushnumber",
#   you might not be linking to the correct (32-bit or 64-bit) version of lua51.lib.
# MinGW may give the error "lua51.dll: file not recognized" on 32-bit/64-bit mismatch.
