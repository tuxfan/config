#include <iostream>
#include <type_traits>

template<typename T>
concept Integer = std::is_integral_v<T>;

template<Integer T>
void print(T t) {
  std::cout << "Integer value: " << t << std::endl;
}

int main(int argc, char ** argv) {
  int i = 10;
  double d = 10.0;
  print(i);
  print(d);
  return 0;
} // main
