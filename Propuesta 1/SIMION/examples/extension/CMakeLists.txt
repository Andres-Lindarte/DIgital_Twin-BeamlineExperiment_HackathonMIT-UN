# CMake build file for simple.dll.
# This is an alternative to Makefile if you want to build simple.dll
# with CMake (www.cmake.org) rather than make/nmake.

project(simple C CXX)
cmake_minimum_required(VERSION 2.6)

# SIMION program directory.
set(SIMIONPATH "c:/Program Files/SIMION-8.1")

# Select 32-bit or 64-bit libraries based on compiler pointer size
# (8 bytes = 64 bit, 4 bytes = 32 bit).
# Note: In 64-bit SIMION, 32-bit libraries are in an "x32" subdirectory.
if (CMAKE_SIZEOF_VOID_P EQUAL 4 AND EXISTS "${SIMIONPATH}/x32")
  set(SIMIONLIB "${SIMIONPATH}/x32/lib/cpp") # use 32-bit libraries
else ()
  set(SIMIONLIB "${SIMIONPATH}/lib/cpp") # use whatever libraries we have
endif ()

# Allow compiler to find Lua includes (e.g. lua.h).
include_directories("${SIMIONPATH}/lib/cpp")

# Build simple.dll library and link against lua51.lib.
add_library(simple MODULE simple.c)
target_link_libraries(simple "${SIMIONLIB}/lua51.lib")
