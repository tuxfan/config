import math
from collections.abc import Callable

import numpy as np


class Bernstein(object):
    """
    Class to handle Bernstein polynomials of degree n
    """

    def __init__(self, deg: int):
        self.deg = deg
        self._bernstein_pol: Callable | None = None
        self._coefficients: np.ndarray | None = None

    def basis(self, nu: int) -> Callable:
        """
        Bernstein basis for nu and n
        """

        assert nu <= self.deg
        assert nu >= 0

        coef = math.comb(self.deg, nu)

        def inner(x: float) -> float:
            return coef * x ** nu * (1 - x) ** (self.deg - nu)

        return inner

    def calculate_transform(self, xarr: np.ndarray, yarr: np.ndarray) -> None:
        """
        Calculate the transformation from the reference x to the values y
        """

        # NOTE:
        # The following two trivial transformations assume that the reference
        # points include the boundary
        match self.deg:
            case 1:
                self._coefficients = np.copy(yarr)
            case 2:
                self._coefficients = np.copy(yarr)
                self._coefficients[1] = (yarr[1]
                                         - yarr[0] * self.basis(0)(xarr[1])
                                         - yarr[2] * self.basis(2)(xarr[1]))
                self._coefficients[1] /= self.basis(1)(xarr[1])
            case _:
                # Create matrix
                mat = np.zeros((xarr.size, xarr.size))
                mat[0][0] = 1
                mat[-1][-1] = 1
                for i in range(1, xarr.size - 1):
                    x = xarr[i]
                    for j in range(xarr.size):
                        mat[i][j] = self.basis(j)(x)

                self._coefficients = np.linalg.solve(mat, yarr)

    def bernstein_pol(self) -> Callable:
        """
        Bernstein polynomial of degree n
        Take the coefficients as a list of length n + 1
        """

        if self._bernstein_pol is not None:
            return self._bernstein_pol

        assert self._coefficients is not None
        assert len(self._coefficients) == self.deg + 1

        # Generate the list of basis functions
        f_list = [self.basis(i) for i in range(self.deg + 1)]

        def inner(x: float) -> float:
            assert self._coefficients is not None
            return np.sum(
                np.fromiter((c * f(x) for c, f in
                             zip(self._coefficients, f_list)), dtype=float))
        self._bernstein_pol = inner

        return self._bernstein_pol


def test_poly(deg: int, ref_points: np.ndarray, real_points: np.ndarray
              ) -> None:
    """
    Test the transformation
    """

    bernstein_deg = Bernstein(deg)
    bernstein_deg.calculate_transform(ref_points, real_points)

    print("\n====================")
    print(f"Transformation of degree {deg}")
    print("====================\n")
    print(f"bernstein_deg._coefficients = {bernstein_deg._coefficients}")

    poly = bernstein_deg.bernstein_pol()
    for x in np.linspace(ref_points[0], ref_points[-1], 11):
        print(f"poly({x:.2f}) = {poly(x):.2f}")


def main() -> None:
    """
    Test a transformation using an arbitrary bernstein polynomial basis
    """

    # Lineal polynomial
    deg = 1
    ref_points = np.array([0, 1])
    real_points = np.array([4, 10])
    test_poly(deg, ref_points, real_points)

    # Quadratic polynomial
    deg = 2
    ref_points = np.array([0, 0.5, 1])
    real_points = np.array([2, 4.2, 10])
    test_poly(deg, ref_points, real_points)

    # Cubic polynomial
    deg = 3
    ref_points = np.array([0, 1 / 3, 2 / 3, 1])
    real_points = np.array([2, 2.1, 5.8, 10])
    test_poly(deg, ref_points, real_points)


if __name__ == "__main__":
    main()
