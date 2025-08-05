import pygame
import numpy as np
import sys

class GameOfLife:
    def __init__(self, width=800, height=600, cell_size=10):
        pygame.init()
        self.width = width
        self.height = height
        self.cell_size = cell_size
        
        # Calculate grid dimensions
        self.cols = width // cell_size
        self.rows = height // cell_size
        
        # Screen setup
        self.screen = pygame.display.set_mode((width, height))
        pygame.display.set_caption("Conway's Game of Life")
        
        # Colors
        self.BLACK = (0, 0, 0)
        self.WHITE = (255, 255, 255)
        self.GREEN = (0, 255, 0)
        
        # Grid initialization
        self.grid = np.zeros((self.rows, self.cols))
        self.randomize_grid(0.3)
        
        # State variables
        self.running = True
        self.paused = False
        self.clock = pygame.time.Clock()
    
    def randomize_grid(self, probability=0.3):
        self.grid = np.random.choice([0, 1], size=(self.rows, self.cols), 
                                      p=[1-probability, probability])
    
    def count_neighbors(self, x, y):
        # Wrap-around grid
        total = 0
        for i in range(-1, 2):
            for j in range(-1, 2):
                row = (x + i + self.rows) % self.rows
                col = (y + j + self.cols) % self.cols
                total += self.grid[row, col]
        return total - self.grid[x, y]
    
    def update(self):
        if self.paused:
            return
        
        new_grid = self.grid.copy()
        for x in range(self.rows):
            for y in range(self.cols):
                live_neighbors = self.count_neighbors(x, y)
                
                if self.grid[x, y] == 1:
                    if live_neighbors < 2 or live_neighbors > 3:
                        new_grid[x, y] = 0
                else:
                    if live_neighbors == 3:
                        new_grid[x, y] = 1
        
        self.grid = new_grid
    
    def draw(self):
        self.screen.fill(self.BLACK)
        
        for x in range(self.rows):
            for y in range(self.cols):
                color = self.GREEN if self.grid[x, y] == 1 else self.BLACK
                rect = pygame.Rect(y*self.cell_size, x*self.cell_size, 
                                   self.cell_size-1, self.cell_size-1)
                pygame.draw.rect(self.screen, color, rect)
        
        pygame.display.update()
    
    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    self.paused = not self.paused
                elif event.key == pygame.K_r:
                    self.randomize_grid()
            
            if event.type == pygame.MOUSEBUTTONDOWN:
                x, y = pygame.mouse.get_pos()
                grid_x = y // self.cell_size
                grid_y = x // self.cell_size
                self.grid[grid_x, grid_y] = 1 - self.grid[grid_x, grid_y]
    
    def run(self):
        while self.running:
            self.handle_events()
            self.update()
            self.draw()
            self.clock.tick(20)  # Control simulation speed
        
        pygame.quit()
        sys.exit()

def main():
    game = GameOfLife(width=1600, height=1200, cell_size=20)
    game.run()

if __name__ == "__main__":
    main()
