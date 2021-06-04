#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <windows.h>
#include <conio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <cmath>
using namespace std;

//Kernel, deals with movements. Nvidia GPU Global Memory
__global__ void gameKernel(int* Md, int* Nd, int* Pd, int Width, int h)
{
	int currently = threadIdx.x + blockDim.x * blockIdx.x;
	int Row = currently / Width;
	int Col = currently - (Width * Row);

	int Pvalue = 0;
	if (Col > 0) { if (1 == Md[currently - 1]) { Pvalue += 1; } }//Left
	if (Col < Width - 1) { if (1 == Md[currently + 1]) { Pvalue += 1; } }//Right
	if (Row > 0) { if (1 == Md[currently - Width]) { Pvalue += 1; } }//Up
	if (Row < Width - 1) { if (1 == Md[currently + Width]) { Pvalue += 1; } }//Down
	if (Col > 0 && Row > 0) { if (1 == Md[currently - Width - 1]) { Pvalue += 1; } }//Left diagonal up
	if (Col < Width - 1 && Row > 0) { if (1 == Md[currently - Width + 1]) { Pvalue += 1; } }//Right diagonal up
	if (Col > 0 && Row < Width - 1) { if (1 == Md[currently + Width - 1]) { Pvalue += 1; } }//Left diagonal down
	if (Col < Width - 1 && Row < Width - 1) { if (1 == Md[currently + Width + 1]) { Pvalue += 1; } }//Right diagonal down

	int value = 0;
	if (0 == Md[Row * Width + Col]) { if (Pvalue == 3) { value = 1; } }

	if (1 == Md[Row * Width + Col]) {
		if ((Pvalue == 2 || Pvalue == 3)) { value = 1; }
		else { value = 0; }
	}

	Nd[currently] = value;
	Pd[currently] = value;
}


//Function that shows the board
void printBoard(int* board, int width, int height) {
	printf("\n\n-----------------------------------------------------------------------------------------------------------------\n\n");
	char columnLetter = 'A';
	cout << "    " << columnLetter << " ";
	for (int i = 1; i < width; i++) {
		columnLetter++;
		cout << columnLetter << " ";
		if (columnLetter == 'Z') { columnLetter = '@'; }
	}

	cout << "\n\n";
	int rowNumber = 0;
	for (int j = 0; j < height; j++) {
		if (rowNumber < 9)
			cout << " " << rowNumber + 1 << "  ";
		else
			cout << " " << rowNumber + 1 << " ";
		for (int k = 0; k < width; k++) {
			if (board[(j * width) + k] == 1) {
				cout << "X" << " ";
			}
			else {
				cout << " " << " ";
			}
		}
		printf("\n");
		rowNumber++;
	}
}

//Function that launches the kernel
void playOnDevice(int* M, int* N, int* P, int w, const int h)
{
	int size = w * h * sizeof(float);
	int* Md;
	int* Pd;
	int* Nd;

	cudaMalloc(&Md, size); //allocate the memory on the GPU
	cudaMemcpy(Md, M, size, cudaMemcpyHostToDevice); //Host to device
	cudaMalloc(&Nd, size);				cudaMalloc(&Pd, size); //allocate the memory on the GPU

	gameKernel << < 1, w* h >> > (Md, Nd, Pd, w, h); //launch kernel

	cudaMemcpy(P, Pd, size, cudaMemcpyDeviceToHost);			cudaMemcpy(N, Nd, size, cudaMemcpyDeviceToHost);
	cudaFree(Md); cudaFree(Nd);  cudaFree(Pd);
}


//To ask for the width and validate it
int* askWidth(int threadsBlockX) {
	int* width = new int;
	cout << "\nEnter the width of the board: ";
	cin >> *width;
	while (cin.fail() || (*width < 0) || (*width > threadsBlockX)) {
		cout << "\nERROR: incorrect width, please try again: ";
		cin.clear();
		cin.ignore(256, '\n');
		cin >> *width;
	}
	return width;
}

//To ask for the height and validate it
int* askHeight(int threadsBlockY) {
	int* height = new int;
	cout << "\nEnter the height of the board: ";
	cin >> *height;
	while (cin.fail() || (*height < 0) || (*height > threadsBlockY)) {
		cout << "\nERROR: incorrect height, please try again: ";
		cin.clear();
		cin.ignore(256, '\n');
		cin >> *height;
	}
	return height;
}


//Function that creates the board with random 1's and 0's
int* createBoard(int height, int width) {

	time_t t;
	srand((unsigned)time(&t));
	int boardSize = width * height;
	int* board = new int[boardSize];
	for (int i = 0; i < height * width; i++) {
		board[i] = (int)rand() % 2;
	}
	return board;
}


//******************
//** MAIN FUNCION **
//******************
int main() {
	cudaDeviceProp properties;
	cudaGetDeviceProperties(&properties, 0);
	int threadsPerBlock = properties.maxThreadsPerBlock;
	int threadsBlockX = properties.maxThreadsDim[0];
	int threadsBlockY = properties.maxThreadsDim[1];
	int* board = new int;
	int* height = new int;
	int* width = new int;
	int* boardR = new int;
	cout << "\nWelcome to the Game of Life \n";
	boolean m = true;
	while (m) {
		width = askWidth(threadsBlockX);
		height = askHeight(threadsBlockY);
		if (((*width) * (*height)) <= threadsPerBlock) {
			m = false;
		}
		else { cout << "\nToo many threads, decrease dimensions\n"; }
	}

	board = createBoard(*width, *height);
	boardR = createBoard(*width, *height);

	char mode;
	cout << "\nChoose the game mode (a/m): ";
	cin >> mode;
	while (cin.fail() || ((mode != 'a') && (mode != 'm'))) {
		cout << "\nERROR: wrong mode, please try again: ";
		cin.clear();
		cin.ignore(256, '\n');
		cin >> mode;
	}

	if (mode == 'a') {
		printBoard(board, *width, *height);
		while (!kbhit())
		{
			playOnDevice(board, board, boardR, *width, *height);
			printBoard(boardR, *width, *height);
			Sleep(500);
		}
	}
	else {
		printBoard(board, *width, *height);
		while (mode != 's')
		{
			playOnDevice(board, board, boardR, *width, *height);
			cout << "\nTo continue type any letter, and to quit 's': ";
			cin >> mode;
			if (mode != 's') { printBoard(boardR, *width, *height);}
		}
	}

	system("pause");
	return(0);
}

