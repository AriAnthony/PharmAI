import numpy as np
import time
import colorama
from colorama import Fore, Style

# Initialize colorama
colorama.init(autoreset=True)

class GameOfLife:
    def __init__(self, size=20, prob=0.25):
        self.size = size
        self.grid = np.random.choice([0, 1], size=(size, size), p=[1-prob, prob])
    
    def count_neighbors(self, x, y):
        neighbors = self.grid[max(0, x-1):min(x+2, self.size), 
                               max(0, y-1):min(y+2, self.size)]
        return np.sum(neighbors) - self.grid[x, y]
    
    def update(self):
        new_grid = self.grid.copy()
        for x in range(self.size):
            for y in range(self.size):
                live_neighbors = self.count_neighbors(x, y)
                
                if self.grid[x, y] == 1:
                    if live_neighbors < 2 or live_neighbors > 3:
                        new_grid[x, y] = 0
                else:
                    if live_neighbors == 3:
                        new_grid[x, y] = 1
        
        self.grid = new_grid
    
    def display(self):
        for row in self.grid:
            colored_row = ''.join([
                f"{Fore.GREEN}●{Style.RESET_ALL}" if cell else f"{Fore.LIGHTBLACK_EX}○{Style.RESET_ALL}" 
                for cell in row
            ])
            print(colored_row)
        print("\n")

def main():
    try:
        game = GameOfLife(size=50, prob=0.3)
        generations = 100
        
        for gen in range(generations):
            print(f"Generation {gen}:")
            game.display()
            game.update()
            time.sleep(0.05)
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()