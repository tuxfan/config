################################################################################
# Test Project Makefile
################################################################################

TARGET=test

CXX=g++
CXXFLAGS=-g -std=c++17 -I.

OBJECTS=main.o

all: ${TARGET}

%.o: %.cc
	${CXX} ${CXXFLAGS} -c $< -o $@

${TARGET}: ${OBJECTS}
	${CXX} ${CXXFLAGS} -o ${TARGET} ${OBJECTS}

clean:
	rm -rf ${OBJECTS} ${TARGET}
