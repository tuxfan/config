#include <iostream>

int main(int argc, char ** argv) {

  const auto S{4};

  auto off{0};
  for(auto j{0}; j<S; ++j) {
    for(auto i{0}; i<S; ++i) {
      std::cout << "offset: " << off << " has (i, j): " << i << ", " << j << std::endl;
      std::cout << "offset%S: " << off%S << " offset/S: " << off/S << std::endl;
      ++off;
    }
  }

	return 0;
} // main
