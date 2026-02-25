#include <iostream>
#include <array>

#define UNUSED(variable) [[ maybe_unused ]] auto variable


int main(int , char ** ) {

  std::array<int, 5> a;
  int i{0};
  for(UNUSED(m): a) {
    std::cout << i++ << std::endl;
  }

	return 0;
} // main
