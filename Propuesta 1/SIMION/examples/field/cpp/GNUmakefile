# GNU makefile for g++ compiler.

SL_LIB=../../../lib/cpp

CXX=c++ -Wall -g -mno-cygwin
CC=$(CXX)
CXXFLAGS=-g -I$(SL_LIB)
VPATH=$(SL_LIB)/simion


all : field

field : field.o pa.o

run :
	./field.exe

purge : clean
	rm -f field.exe

clean :
	rm -f *~ *.stackdump *.o mag[12].pa
	rm -fr *.plg Release Debug