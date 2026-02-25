#include <iostream>
#include <type_traits>

template<typename T>
concept arithmetic = std::is_arithmetic_v<T>;

template<int M>
concept size_type = M<=10;

template<arithmetic T>
void print(T t) {
  std::cout << "T: " << t << std::endl;
}

int main(int argc, char ** argv) {
  {
  double v{10.0};
  print(v);
  }

  {
  int v{5};
  print(v);
  }
	return 0;
} // main
