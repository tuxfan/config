#include <mfem.hpp>
#include <iostream>

using namespace std;
using namespace mfem;

#define DIM 3

int main(int argc, char ** argv) {

  if(argc < 2) {
    std::cerr << "Usage: " << argv[0] << " order" << std::endl;
    std::exit(1);
  }

  int order = atoi(argv[1]);

  Mesh mesh =
      DIM == 2 ? Mesh::MakeCartesian2D(1, 1, mfem::Element::Type::QUADRILATERAL,
                                       true, 1.0, 1.0, true)
               : Mesh::MakeCartesian3D(1, 1, 1, mfem::Element::Type::HEXAHEDRON,
                                       1.0, 1.0, 1.0, true);

  const int dim = mesh.Dimension();
  H1_FECollection fec(order, dim);
  FiniteElementSpace fes(&mesh, &fec, dim);
  GridFunction nodes(&fes);
  mesh.GetNodes(nodes);
  const int nNodes = nodes.Size() / dim;
  double coord[DIM]; // coordinates of a node
  for (int i = 0; i < nNodes; ++i) {
    for (int j = 0; j < dim; ++j) {
      coord[j] = nodes(j * nNodes + i); 
      std::cout << coord[j] << " ";
    }   
    std::cout << std::endl;
  }
  return 0;
}
