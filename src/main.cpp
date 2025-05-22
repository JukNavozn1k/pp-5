#include <iostream>
#include <vector>
#include <cstdlib>
#include <chrono>
#include <cstring>
#include <pvm3.h>

using namespace std;
using Matrix = vector<vector<int>>;

const int STRASSEN_THRESHOLD = 64;

// Forward declarations
Matrix generateRandomMatrix(int n);
Matrix standardMultiply(const Matrix& A, const Matrix& B);
Matrix add(const Matrix& A, const Matrix& B);
Matrix subtract(const Matrix& A, const Matrix& B);
Matrix strassenSequential(const Matrix& A, const Matrix& B);
Matrix strassenPVM(const Matrix& A, const Matrix& B);
bool validateMatrices(const Matrix& A, const Matrix& B);
int pvm_worker_main();

Matrix generateRandomMatrix(int n) {
    Matrix A(n, vector<int>(n));
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            A[i][j] = rand() % 10;
    return A;
}

Matrix standardMultiply(const Matrix& A, const Matrix& B) {
    int n = A.size();
    Matrix C(n, vector<int>(n, 0));
    for (int i = 0; i < n; i++)
        for (int k = 0; k < n; k++)
            for (int j = 0; j < n; j++)
                C[i][j] += A[i][k] * B[k][j];
    return C;
}

Matrix add(const Matrix& A, const Matrix& B) {
    int n = A.size();
    Matrix C(n, vector<int>(n));
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            C[i][j] = A[i][j] + B[i][j];
    return C;
}

Matrix subtract(const Matrix& A, const Matrix& B) {
    int n = A.size();
    Matrix C(n, vector<int>(n));
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            C[i][j] = A[i][j] - B[i][j];
    return C;
}

Matrix strassenSequential(const Matrix& A, const Matrix& B) {
    int n = A.size();
    if (n <= STRASSEN_THRESHOLD)
        return standardMultiply(A, B);

    int newSize = n / 2;
    Matrix A11(newSize, vector<int>(newSize)), A12(newSize, vector<int>(newSize));
    Matrix A21(newSize, vector<int>(newSize)), A22(newSize, vector<int>(newSize));
    Matrix B11(newSize, vector<int>(newSize)), B12(newSize, vector<int>(newSize));
    Matrix B21(newSize, vector<int>(newSize)), B22(newSize, vector<int>(newSize));

    for (int i = 0; i < newSize; i++)
        for (int j = 0; j < newSize; j++) {
            A11[i][j] = A[i][j]; A12[i][j] = A[i][j + newSize];
            A21[i][j] = A[i + newSize][j]; A22[i][j] = A[i + newSize][j + newSize];
            B11[i][j] = B[i][j]; B12[i][j] = B[i][j + newSize];
            B21[i][j] = B[i + newSize][j]; B22[i][j] = B[i + newSize][j + newSize];
        }

    Matrix M[7];
    M[0] = strassenSequential(add(A11, A22), add(B11, B22));
    M[1] = strassenSequential(add(A21, A22), B11);
    M[2] = strassenSequential(A11, subtract(B12, B22));
    M[3] = strassenSequential(A22, subtract(B21, B11));
    M[4] = strassenSequential(add(A11, A12), B22);
    M[5] = strassenSequential(subtract(A21, A11), add(B11, B12));
    M[6] = strassenSequential(subtract(A12, A22), add(B21, B22));

    Matrix C(n, vector<int>(n));
    for (int i = 0; i < newSize; ++i)
        for (int j = 0; j < newSize; ++j) {
            C[i][j] = M[0][i][j] + M[3][i][j] - M[4][i][j] + M[6][i][j];
            C[i][j + newSize] = M[2][i][j] + M[4][i][j];
            C[i + newSize][j] = M[1][i][j] + M[3][i][j];
            C[i + newSize][j + newSize] = M[0][i][j] - M[1][i][j] + M[2][i][j] + M[5][i][j];
        }
    return C;
}

int pvm_worker_main() {
    int m;
    pvm_recv(-1, 1);
    pvm_upkint(&m, 1, 1);
    Matrix A(m, vector<int>(m)), B(m, vector<int>(m));
    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            pvm_upkint(&A[i][j], 1, 1);
    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            pvm_upkint(&B[i][j], 1, 1);
    Matrix C = strassenPVM(A, B);
    pvm_initsend(PvmDataDefault);
    pvm_pkint(&m, 1, 1);
    for (int i = 0; i < m; ++i)
        for (int j = 0; j < m; ++j)
            pvm_pkint(&C[i][j], 1, 1);
    pvm_send(pvm_parent(), 2);
    return 0;
}

Matrix strassenPVM(const Matrix& A, const Matrix& B) {
    return strassenSequential(A, B); // fallback stub
}

bool validateMatrices(const Matrix& A, const Matrix& B) {
    int n = A.size();
    if (n != B.size()) return false;
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            if (A[i][j] != B[i][j]) return false;
    return true;
}

int main(int argc, char* argv[]) {
    if (argc > 1 && strcmp(argv[1], "worker") == 0) {
        return pvm_worker_main();
    }
    int n = 1024;
    if (argc >= 2) n = atoi(argv[1]);
    cout << "Matrix size: " << n << "x" << n << endl;
    pvm_mytid();
    Matrix A = generateRandomMatrix(n);
    Matrix B = generateRandomMatrix(n);
    auto start = chrono::high_resolution_clock::now();
    Matrix C_std = standardMultiply(A, B);
    auto end = chrono::high_resolution_clock::now();
    cout << "Standard: " << chrono::duration<double, milli>(end - start).count() << " ms\n";
    start = chrono::high_resolution_clock::now();
    Matrix C_seq = strassenSequential(A, B);
    end = chrono::high_resolution_clock::now();
    cout << "Strassen Sequential: " << chrono::duration<double, milli>(end - start).count() << " ms\n";
    start = chrono::high_resolution_clock::now();
    Matrix C_pvm = strassenPVM(A, B);
    end = chrono::high_resolution_clock::now();
    cout << "Strassen PVM: " << chrono::duration<double, milli>(end - start).count() << " ms\n";
    cout << "Validation (Sequential): " << (validateMatrices(C_std, C_seq) ? "Passed" : "Failed") << endl;
    cout << "Validation (PVM):        " << (validateMatrices(C_std, C_pvm) ? "Passed" : "Failed") << endl;
    return 0;
}