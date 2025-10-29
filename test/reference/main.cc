#include <iostream>
#include <cstddef>

enum shape {
  seg2,
  tri3,
  quad4,
  tet4,
  hex8
};

template<std::size_t D, shape S, std::size_t PO, bool C>
struct reference_element;

template<std::size_t PO>
struct reference_element<1, shape::seg2, PO, true> {
  void print() { std::cout << "shape: seg2" << std::endl; }
};

template<std::size_t PO>
struct reference_element<2, shape::tri3, PO, true> {
  void print() { std::cout << "shape: tri3" << std::endl; }
};

template<std::size_t PO>
struct reference_element<2, shape::quad4, PO, true> {
  void print() { std::cout << "shape: quad4" << std::endl; }
};

template<std::size_t PO>
struct reference_element<3, shape::tet4, PO, true> {
  void print() { std::cout << "shape: tet4" << std::endl; }
};

template<std::size_t PO>
struct reference_element<3, shape::hex8, PO, true> {
  void print() { std::cout << "shape: hex8" << std::endl; }
};

template<std::size_t D>
constexpr shape hypercube_shape() {
  if constexpr (D == 1) { return shape::seg2; }
  else if constexpr (D == 2) { return shape::quad4; }
  else /* D == 3 */ { return shape::hex8; }
}

template<std::size_t D>
constexpr shape simplex_shape() {
  if constexpr (D == 1) { return shape::seg2; }
  else if constexpr (D == 2) { return shape::tri3; }
  else /* D == 3 */ { return shape::tet4; }
}

template<std::size_t D, std::size_t PO, bool C>
using hypercube_reference_element = reference_element<D, hypercube_shape<D>(), PO, C>;
template<std::size_t D, std::size_t PO, bool C>
using simplex_reference_element = reference_element<D, simplex_shape<D>(), PO, C>;

template<std::size_t D, std::size_t PO>
using kinematic_href = hypercube_reference_element<D, PO, true>;

template<std::size_t D, std::size_t PO>
void test_ref() {
  kinematic_href<D, PO> re;
  re.print();
}

int main(int argc, char ** argv) {
  test_ref<1,1>();
  test_ref<2,1>();
  test_ref<3,1>();
	return 0;
} // main
