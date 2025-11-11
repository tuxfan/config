#------------------------------------------------------------------------------#
# CMakeLists.txt
#------------------------------------------------------------------------------#

cmake_minimum_required(VERSION 3.12)

project(Test LANGUAGES CXX C)

set(CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(FleCSI 2 REQUIRED)

add_executable(test driver.cc)
target_link_libraries(test FleCSI::FleCSI)
