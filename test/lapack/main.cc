#include <iostream>
#include <lapacke.h>

int main(int argc, char ** argv) {

  double m[3][3] = {
    { 2.0, -1.0, -2.0 },
    { -4.0, 6.0, 3.0 },
    { -4.0, -2.0, 8.0 }
  };
  int32_t p[3];

  LAPACKE_dgetrf(LAPACK_COL_MAJOR, 3, 3, &m[0][0], 3, &p[0]);

  for(int j{0}; j<3; ++j) {
    for(int i{0}; i<3; ++i) {
      std::cout << m[j][i] << " ";
    }
    std::cout << std::endl;
  }

  for(int j{0}; j<3; ++j) {
    std::cout << p[j] << std::endl;
  }
  

	return 0;
} // main
