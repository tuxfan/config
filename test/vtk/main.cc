#include <vtkSmartPointer.h>
#include <vtkXMLUnstructuredGridReader.h>
#include <vtkUnstructuredGrid.h>
#include <vtkCell.h>
#include <vtkPoints.h>
#include <iostream>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " input.vtu" << std::endl;
        return EXIT_FAILURE;
    }

    std::string filename = argv[1];

    // 1. Initialize the reader for .vtu files
    auto reader = vtkSmartPointer<vtkXMLUnstructuredGridReader>::New();
    reader->SetFileName(filename.c_str());
    reader->Update();

    // 2. Get the unstructured grid output
    vtkUnstructuredGrid* ugrid = reader->GetOutput();
    vtkPoints* points = ugrid->GetPoints();

    int numCells = ugrid->GetNumberOfCells();
    std::cout << "Mesh contains " << numCells << " cells." << std::endl;

    // 3. Iterate through each cell
    for (vtkIdType cellId = 0; cellId < numCells; ++cellId) {
        vtkCell* cell = ugrid->GetCell(cellId);
        int numPoints = cell->GetNumberOfPoints();

        std::cout << "Cell " << cellId << " (Type: " << cell->GetCellType() 
                  << ") has " << numPoints << " vertices:" << std::endl;

        // 4. Print coordinates for each vertex in the cell
        for (int i = 0; i < numPoints; ++i) {
            vtkIdType pointId = cell->GetPointId(i);
            double coords[3];
            points->GetPoint(pointId, coords);

            std::cout << "  Vertex " << i << " [ID " << pointId << "]: (" 
                      << coords[0] << ", " << coords[1] << ", " << coords[2] << ")" << std::endl;
        }
        std::cout << "-----------------------------------" << std::endl;
    }

    return EXIT_SUCCESS;
}
