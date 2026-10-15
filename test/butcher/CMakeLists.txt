#------------------------------------------------------------------------------#
# CMakeLists.txt
#------------------------------------------------------------------------------#

cmake_minimum_required(VERSION 3.12)

project(Test LANGUAGES CXX C)

set(CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)
set(CMAKE_CXX_FLAGS "-g -O2 -std=c++20 -fcolor-diagnostics -I.")

add_executable(test main.cc)
