# GNU makefile for g++ compiler.

SL_LIB=../../../lib/cpp

CXX=c++
#CXX=i686-pc-cygwin-g++       # 32-bit Cygwin compiler
#CXX=i686-w64-mingw32-g++     # 32-bit native compiler
#CXX=x86_64-w64-mingw32-g++   # 64-bit native compiler

CC=$(CXX)
CXXFLAGS=-I$(SL_LIB) -Wall -O2
LDFLAGS=-static-libstdc++ -static-libgcc  # static link C/C++ standard libs
VPATH=$(SL_LIB)/simion

all : swirl

swirl   : swirl.o pa.o
swirl.o : swirl.cpp

run :
	./swirl.exe

purge : clean
	rm -f swirl.exe

clean :
	rm -f *~ *.stackdump *.o swirl.pa\#
	rm -fr *.plg Release Debug