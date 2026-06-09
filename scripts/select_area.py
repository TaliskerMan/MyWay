#!/usr/bin/env python3
import sys
import tkinter as tk

class AreaSelector:
    def __init__(self):
        self.root = tk.Tk()
        
        # Make the window borderless
        self.root.overrideredirect(True)
        
        # Make the window cover the entire screen
        self.screen_width = self.root.winfo_screenwidth()
        self.screen_height = self.root.winfo_screenheight()
        self.root.geometry(f"{self.screen_width}x{self.screen_height}+0+0")
        
        # Keep window on top
        self.root.wm_attributes("-topmost", True)
        
        # Set alpha transparency (requires a compositor like Compton, GNOME, etc.)
        self.root.attributes("-alpha", 0.35)
        
        # Config cursor to crosshair
        self.root.config(cursor="crosshair")
        
        # Canvas for drawing selection
        self.canvas = tk.Canvas(self.root, cursor="crosshair", bg="#101010", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        
        self.canvas.bind("<ButtonPress-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)
        
        # Bind Escape and Q to exit without selection
        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.root.bind("<q>", lambda e: self.root.destroy())
        
        self.start_x = None
        self.start_y = None
        self.rect_id = None
        self.result = None

    def on_press(self, event):
        self.start_x = event.x
        self.start_y = event.y
        # Create rectangle outline with a teal/cyan color (MyWay theme)
        self.rect_id = self.canvas.create_rectangle(
            self.start_x, self.start_y, self.start_x, self.start_y,
            outline="#00bfa5", width=3
        )

    def on_drag(self, event):
        cur_x, cur_y = event.x, event.y
        self.canvas.coords(self.rect_id, self.start_x, self.start_y, cur_x, cur_y)

    def on_release(self, event):
        end_x = event.x
        end_y = event.y
        
        x = min(self.start_x, end_x)
        y = min(self.start_y, end_y)
        w = abs(self.start_x - end_x)
        h = abs(self.start_y - end_y)
        
        if w > 10 and h > 10:
            self.result = (x, y, w, h)
        
        self.root.destroy()

    def run(self):
        self.root.mainloop()
        return self.result

if __name__ == "__main__":
    selector = AreaSelector()
    res = selector.run()
    if res:
        print(f"{res[0]} {res[1]} {res[2]} {res[3]}")
        sys.exit(0)
    else:
        sys.exit(1)
