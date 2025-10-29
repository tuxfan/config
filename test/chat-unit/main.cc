// test_reference_element.cc
#include <cassert>
#include <cmath>
#include <cstddef>
#include <iostream>
#include <type_traits>

#include "types.hh" // adjust include path as needed

using hydro::kinematic_reference;
using hydro::thermodynamic_reference;
using hydro::shape;
namespace pts = hydro::pts;
using hydro::uv;

template <typename T>
inline double dcast(T v) { return static_cast<double>(v); }

inline bool approx(double a, double b, double eps = 1e-12) {
  return std::fabs(a - b) <= eps * std::max(1.0, std::max(std::fabs(a), std::fabs(b)));
}

constexpr std::size_t ipow(std::size_t a, std::size_t b) {
  std::size_t r = 1;
  for (std::size_t i = 0; i < b; ++i) r *= a;
  return r;
}

// Count how many coordinates are at an "extreme" (c0 or c1)
template <std::size_t D>
std::size_t count_extremes(const std::array<double, D>& p,
                           double c0, double c1, double eps = 1e-12) {
  std::size_t c = 0;
  for (std::size_t k = 0; k < D; ++k) {
    double v = dcast(p[k]);
    if (approx(v, c0, eps) || approx(v, c1, eps)) ++c;
  }
  return c;
}

/*========================== 1D: seg2 ==========================*/
template <std::size_t PO, template<std::size_t> class B>
void test_seg2() {
  // Thermodynamic (discontinuous): always valid for PO >= 0
  {
    using T = thermodynamic_reference<shape::seg2, PO, B>;
    T e;
    const auto dofs = e.dofs();
    assert(dofs.size() == PO + 1);

    const auto& C = e.coords();
    if constexpr (PO == 0) {
      // Single node at 0.5
      auto id = *dofs.begin();
      assert(approx(dcast(C[id][uv::i]), dcast(B<PO>::coord(0))));
      assert(approx(dcast(C[id][uv::i]), 0.5));
    } else {
      // Endpoints at 0 and 1
      auto first = *dofs.begin();
      auto last  = *(dofs.begin() + (dofs.size() - 1));
      assert(approx(dcast(C[first][uv::i]), dcast(B<PO>::coord(0))));
      assert(approx(dcast(C[last ][uv::i]), dcast(B<PO>::coord(PO))));
    }
  }

  // Kinematic (continuous): valid for PO >= 1
  if constexpr (PO >= 1) {
    using K = kinematic_reference<shape::seg2, PO, B>;
    K e;
    const auto dofs = e.dofs();
    assert(dofs.size() == PO + 1);

    const auto v = e.vdofs();
    assert(v.size() == 2);
    const auto& C = e.coords();

    // Vertices at 0 and 1
    auto v0 = e.vdof(0);
    auto v1 = e.vdof(1);
    assert(approx(dcast(C[v0][uv::i]), dcast(B<PO>::coord(0))));
    assert(approx(dcast(C[v1][uv::i]), dcast(B<PO>::coord(PO))));

    // Cell-interior DOFs: (PO-1) of them for PO>=2
    const auto cd = e.cdofs();
    if constexpr (PO == 1) {
      assert(cd.size() == 0);
    } else {
      assert(cd.size() == (PO - 1));
      // They should sit at B<PO>::coord(1..PO-1)
      std::size_t i = 1;
      for (auto id : cd) {
        assert(approx(dcast(C[id][uv::i]), dcast(B<PO>::coord(i))));
        ++i;
      }
    }
  }
}

/*========================== 2D: quad4 ==========================*/
template <std::size_t PO, template<std::size_t> class B>
void test_quad4() {
  const std::size_t DOFS1 = PO + 1;

  // Thermo: always valid
  {
    using T = thermodynamic_reference<shape::quad4, PO, B>;
    T e;
    const auto dofs = e.dofs();
    assert(dofs.size() == DOFS1 * DOFS1);

    const auto& C = e.coords();

    double c0 = dcast(B<PO>::coord(0));
    double c1 = dcast(B<PO>::coord(PO));
    if constexpr (PO == 0) {
      // single node at (0.5,0.5)
      auto id = *dofs.begin();
      assert(approx(dcast(C[id][uv::i]), 0.5));
      assert(approx(dcast(C[id][uv::j]), 0.5));
    } else {
      // Corners present at (0,0), (1,0), (1,1), (0,1)
      auto idx = [&](std::size_t i, std::size_t j) { return j * DOFS1 + i; };
      auto id00 = idx(0, 0);
      auto id10 = idx(PO, 0);
      auto id11 = idx(PO, PO);
      auto id01 = idx(0, PO);
      assert(approx(dcast(C[id00][uv::i]), c0) && approx(dcast(C[id00][uv::j]), c0));
      assert(approx(dcast(C[id10][uv::i]), c1) && approx(dcast(C[id10][uv::j]), c0));
      assert(approx(dcast(C[id11][uv::i]), c1) && approx(dcast(C[id11][uv::j]), c1));
      assert(approx(dcast(C[id01][uv::i]), c0) && approx(dcast(C[id01][uv::j]), c1));
    }
  }

  // Kinematic: valid for PO >= 1
  if constexpr (PO >= 1) {
    using K = kinematic_reference<shape::quad4, PO, B>;
    K e;
    const auto dofs = e.dofs();
    assert(dofs.size() == DOFS1 * DOFS1);

    const auto& C = e.coords();
    double c0 = dcast(B<PO>::coord(0));
    double c1 = dcast(B<PO>::coord(PO));

    // Vertices in CCW order: (0,0), (1,0), (1,1), (0,1)
    auto v = e.vdofs();
    assert(v.size() == 4);
    assert(approx(dcast(C[v[0]][uv::i]), c0) && approx(dcast(C[v[0]][uv::j]), c0));
    assert(approx(dcast(C[v[1]][uv::i]), c1) && approx(dcast(C[v[1]][uv::j]), c0));
    assert(approx(dcast(C[v[2]][uv::i]), c1) && approx(dcast(C[v[2]][uv::j]), c1));
    assert(approx(dcast(C[v[3]][uv::i]), c0) && approx(dcast(C[v[3]][uv::j]), c1));

    // Edge DOF counts and location properties
    if constexpr (PO == 1) {
      #if 0
      // piecewise linear specialization: no edge or cell dofs
      for (std::size_t eidx = 0; eidx < 4; ++eidx) {
        assert(::std::span<std::size_t>() == e.edofs(eidx)); // empty span
      }
      #endif
      assert(e.cdofs().size() == 0);
    } else {
      // Each edge has (PO-1) interior DOFs, and each such DOF has exactly 1 extreme coord
      for (std::size_t eidx = 0; eidx < 4; ++eidx) {
        auto ed = e.edofs(eidx);
        assert(ed.size() == (PO - 1));
        for (auto id : ed) {
          auto extremes = count_extremes(C[id], c0, c1);
          assert(extremes == 1);
        }
      }
      // Cell interior has (PO-1)^2 DOFs, none at extremes
      auto cd = e.cdofs();
      assert(cd.size() == (PO - 1) * (PO - 1));
      for (auto id : cd) {
        auto extremes = count_extremes(C[id], c0, c1);
        assert(extremes == 0);
      }
    }
  }
}

/*========================== 3D: hex8 ==========================*/
template <std::size_t PO, template<std::size_t> class B>
void test_hex8() {
  const std::size_t DOFS1 = PO + 1;

  // Thermo: always valid
  {
    using T = thermodynamic_reference<shape::hex8, PO, B>;
    T e;
    const auto dofs = e.dofs();
    assert(dofs.size() == DOFS1 * DOFS1 * DOFS1);

    const auto& C = e.coords();
    if constexpr (PO == 0) {
      auto id = *dofs.begin();
      assert(approx(dcast(C[id][uv::i]), 0.5));
      assert(approx(dcast(C[id][uv::j]), 0.5));
      assert(approx(dcast(C[id][uv::k]), 0.5));
    } else {
      // Spot-check the eight corners
      auto idx = [&](std::size_t i, std::size_t j, std::size_t k) {
        return k * DOFS1 * DOFS1 + j * DOFS1 + i;
      };
      double c0 = dcast(B<PO>::coord(0));
      double c1 = dcast(B<PO>::coord(PO));
      auto chk = [&](std::size_t i, std::size_t j, std::size_t k,
                     double x, double y, double z) {
        auto id = idx(i, j, k);
        assert(approx(dcast(C[id][uv::i]), x) &&
               approx(dcast(C[id][uv::j]), y) &&
               approx(dcast(C[id][uv::k]), z));
      };
      chk(0 , 0 , 0 , c0, c0, c0);
      chk(PO, 0 , 0 , c1, c0, c0);
      chk(PO, PO, 0 , c1, c1, c0);
      chk(0 , PO, 0 , c0, c1, c0);
      chk(0 , 0 , PO, c0, c0, c1);
      chk(PO, 0 , PO, c1, c0, c1);
      chk(PO, PO, PO, c1, c1, c1);
      chk(0 , PO, PO, c0, c1, c1);
    }
  }

  // Kinematic: valid for PO >= 1
  if constexpr (PO >= 1) {
    using K = kinematic_reference<shape::hex8, PO, B>;
    K e;
    const auto dofs = e.dofs();
    assert(dofs.size() == DOFS1 * DOFS1 * DOFS1);

    const auto& C = e.coords();
    double c0 = dcast(B<PO>::coord(0));
    double c1 = dcast(B<PO>::coord(PO));

    // 8 vertices and their coordinates
    auto v = e.vdofs();
    assert(v.size() == 8);
    // (0,0,0)
    assert(approx(dcast(C[v[0]][uv::i]), c0) &&
           approx(dcast(C[v[0]][uv::j]), c0) &&
           approx(dcast(C[v[0]][uv::k]), c0));
    // (1,0,0)
    assert(approx(dcast(C[v[1]][uv::i]), c1) &&
           approx(dcast(C[v[1]][uv::j]), c0) &&
           approx(dcast(C[v[1]][uv::k]), c0));
    // (1,1,0)
    assert(approx(dcast(C[v[2]][uv::i]), c1) &&
           approx(dcast(C[v[2]][uv::j]), c1) &&
           approx(dcast(C[v[2]][uv::k]), c0));
    // (0,1,0)
    assert(approx(dcast(C[v[3]][uv::i]), c0) &&
           approx(dcast(C[v[3]][uv::j]), c1) &&
           approx(dcast(C[v[3]][uv::k]), c0));
    // (0,0,1)
    assert(approx(dcast(C[v[4]][uv::i]), c0) &&
           approx(dcast(C[v[4]][uv::j]), c0) &&
           approx(dcast(C[v[4]][uv::k]), c1));
    // (1,0,1)
    assert(approx(dcast(C[v[5]][uv::i]), c1) &&
           approx(dcast(C[v[5]][uv::j]), c0) &&
           approx(dcast(C[v[5]][uv::k]), c1));
    // (1,1,1)
    assert(approx(dcast(C[v[6]][uv::i]), c1) &&
           approx(dcast(C[v[6]][uv::j]), c1) &&
           approx(dcast(C[v[6]][uv::k]), c1));
    // (0,1,1)
    assert(approx(dcast(C[v[7]][uv::i]), c0) &&
           approx(dcast(C[v[7]][uv::j]), c1) &&
           approx(dcast(C[v[7]][uv::k]), c1));

    if constexpr (PO == 1) {
//      // No edge/face/cell interior dofs
//      for (std::size_t eidx = 0; eidx < 12; ++eidx)
//        assert(::std::span<std::size_t>() == e.edofs(eidx));
//      for (std::size_t fidx = 0; fidx < 6; ++fidx)
//        assert(::std::span<std::size_t>() == e.fdofs(fidx));
      assert(e.cdofs().size() == 0);
    } else {
      // Edges: each has (PO-1) DOFs; every edge-DOF has exactly 2 extremes (two axes fixed)
      for (std::size_t eidx = 0; eidx < 12; ++eidx) {
        auto ed = e.edofs(eidx);
        assert(ed.size() == (PO - 1));
        for (auto id : ed) {
          auto extremes = count_extremes(C[id], c0, c1);
          assert(extremes == 2);
        }
      }
      // Faces: each has (PO-1)^2 DOFs; every face-DOF has exactly 1 extreme (one axis fixed)
      for (std::size_t fidx = 0; fidx < 6; ++fidx) {
        auto fd = e.fdofs(fidx);
        assert(fd.size() == (PO - 1) * (PO - 1));
        for (auto id : fd) {
          auto extremes = count_extremes(C[id], c0, c1);
          assert(extremes == 1);
        }
      }
      // Cell interior: (PO-1)^3 DOFs; no extremes
      auto cd = e.cdofs();
      assert(cd.size() == (PO - 1) * (PO - 1) * (PO - 1));
      for (auto id : cd) {
        auto extremes = count_extremes(C[id], c0, c1);
        assert(extremes == 0);
      }
    }
  }
}

/*========================== Driver ==========================*/

template <template<std::size_t> class B>
void run_all_orders() {
  test_seg2<0, B>();
  test_seg2<1, B>();
  test_seg2<2, B>();
  test_seg2<3, B>();
  test_seg2<4, B>();

  test_quad4<0, B>();
  test_quad4<1, B>();
  test_quad4<2, B>();
  test_quad4<3, B>();
  test_quad4<4, B>();

  test_hex8<0, B>();
  test_hex8<1, B>();
  test_hex8<2, B>();
  test_hex8<3, B>();
  test_hex8<4, B>();
}

int main() {
  // Run against both supported node families
  run_all_orders<pts::equidistant>();
  run_all_orders<pts::gauss_lobatto>();

  std::cout << "All reference_element tests passed for PO = 0..4 (both bases).\n";
  return 0;
}

