#include <cstddef>
#include <iostream>

template<std::size_t D, std::size_t PO>
struct test {
  static void print() {
    std::cout << "default" << std::endl;
  }
};

template<>
struct test<1, 1> {
  static void print() {
    std::cout << "specialized" << std::endl;
  }
};

template<std::size_t PO>
struct test<1, PO> {
  static void print() {
    std::cout << "specialized partial" << std::endl;
  }
};

int main(int argc, char ** argv) {

  test<1,1>::print();
  test<1,2>::print();
  test<2,2>::print();
	return 0;
} // main
