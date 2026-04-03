#include <iostream>
#include <iomanip>
#include <vector>
#include <fstream>
#include <cmath>

struct Vertex {
    double x, y, z;
};

int main() {
    int nx = 8, ny = 8, nz = 8;
    double lx = 1.0, ly = 1.0, lz = 1.0;
    
    // Generate vertices
    std::vector<Vertex> vertices;
    for (int k = 0; k <= nz; ++k) {
        for (int j = 0; j <= ny; ++j) {
            for (int i = 0; i <= nx; ++i) {
                vertices.push_back({
                    (double)i / nx * lx,
                    (double)j / ny * ly,
                    (double)k / nz * lz
                });
            }
        }
    }

    // Generate cells (hexahedrons)
    std::vector<std::vector<int>> cells;
    for (int k = 0; k < nz; ++k) {
        for (int j = 0; j < ny; ++j) {
            for (int i = 0; i < nx; ++i) {
                int n0 = k * (nx + 1) * (ny + 1) + j * (nx + 1) + i;
                int n1 = n0 + 1;
                int n2 = n0 + (nx + 1) + 1;
                int n3 = n0 + (nx + 1);
                int n4 = n0 + (nx + 1) * (ny + 1);
                int n5 = n4 + 1;
                int n6 = n4 + (nx + 1) + 1;
                int n7 = n4 + (nx + 1);
                cells.push_back({n0, n1, n2, n3, n4, n5, n6, n7});
            }
        }
    }

    // Output information
    std::cout << vertices.size() << " " << cells.size() << std::endl;

    for(int i=0; i<vertices.size(); ++i) 
      std::cout << std::setprecision(8) << vertices[i].x << " " << vertices[i].y << " " << vertices[i].z << std::endl;

    for(auto c : cells) {
      for(auto v: c) {
        std::cout << v << " ";
    }
    std::cout << std::endl;
    }

    return 0;
}
