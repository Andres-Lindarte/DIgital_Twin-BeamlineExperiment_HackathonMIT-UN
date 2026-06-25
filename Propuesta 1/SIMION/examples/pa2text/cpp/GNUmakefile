# GNU Makefile for g++ compiler.

SL_LIB=../../../lib/cpp

CXX=c++
#CXX=i686-pc-cygwin-g++       # 32-bit Cygwin compiler
#CXX=i686-w64-mingw32-g++     # 32-bit native compiler
#CXX=x86_64-w64-mingw32-g++   # 64-bit native compiler

CC=$(CXX)
CXXFLAGS=-I$(SL_LIB) -Wall -O2
LDFLAGS=-static-libstdc++ -static-libgcc  # static link C/C++ standard libs
VPATH=$(SL_LIB)/simion

all : pa2text

pa2text   : pa.o pa2text.o
pa.o      : pa.cpp pa.h
pa2text.o : pa2text.cpp pa.h

run :
	./pa2text.exe simple.pa\# > simple.pa\#.txt

purge : clean
	rm -f pa2text.exe

clean :
	rm -f *~ *.stackdump *.o simple.pa\#.txt
	rm -fr *.plg Release Debug
