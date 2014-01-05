#!/usr/bin/env python

import sys
import os, os.path
import subprocess
import Tkinter as tk
from PIL import Image, ImageTk

JPEGTRAN = 'jpegtran'

class GetCropCoordinatesApp(tk.Tk):
    def __init__(self, imageName, results):
        tk.Tk.__init__(self)

        self.results = results
        self.mouse_active = False
        self.x0 = None
        self.x1 = None
        self.y0 = None
        self.y1 = None
        self.canvas = None
        self.rectangle = None

        self.title("Select region to crop")

        image = Image.open(imageName)

        left = 0
        top = 0
        width, height = self.winfo_screenwidth() - 100, self.winfo_screenheight() - 100
        
        imageWidth, imageHeight = image.size
        
        self.xRatio = imageWidth / float(width)
        self.yRatio = imageHeight / float(height)

        image = image.resize((width, height), Image.ANTIALIAS)
    
        image = ImageTk.PhotoImage(image)

        self.geometry('%dx%d+%d+%d' % (width, height, left, top))

        self.canvas = tk.Canvas(self, width=width, height=height, cursor='cross', highlightthickness=0)
        self.canvas.create_image((0, 0), image=image, anchor=tk.NW)
        self.canvas.pack(side='top', fill='both', expand='yes')

        button = tk.Button(self, text="Crop", command=self.on_crop)
        
        self.canvas.create_window(width // 2, height // 2, window=button, anchor=tk.N)

        # To prevent garbage collection to destroy the image
        self.canvas.image = image

        self.canvas.bind('<ButtonPress-1>', self.on_button_press)
        self.canvas.bind('<ButtonRelease-1>', self.on_button_release)
        self.canvas.bind('<B1-Motion>', self.on_mouse_move)

    def normalize_results(self):
        if self.results['left'] is not None:
            self.results['left'] = int(self.results['left'] * self.xRatio)
        if self.results['right'] is not None:
            self.results['right'] = int(self.results['right'] * self.xRatio)
        if self.results['top'] is not None:
            self.results['top'] = int(self.results['top'] * self.yRatio)
        if self.results['bottom'] is not None:
            self.results['bottom'] = int(self.results['bottom'] * self.yRatio)

        if self.results['left'] is not None and self.results['right'] is not None and self.results['right'] < self.results['left']:
            self.results['left'], self.results['right'] = self.results['right'], self.results['left']
        if self.results['top'] is not None and self.results['bottom'] is not None and self.results['bottom'] < self.results['top']:
            self.results['top'], self.results['bottom'] = self.results['bottom'], self.results['top']

    def on_crop(self):
        self.results['left'] = self.x0
        self.results['right'] = self.x1
        self.results['top'] = self.y0
        self.results['bottom'] = self.y1

        self.normalize_results()
        self.destroy()
    
    def draw_rectangle(self):
        if self.rectangle is None:
            self.rectangle = self.canvas.create_rectangle(self.x0, self.y0, self.x1, self.y1, outline='red')
        else:
            self.canvas.coords(self.rectangle, (self.x0, self.y0, self.x1, self.y1))

    def on_button_press(self, event):
        self.mouse_active = True

        self.x0 = event.x
        self.y0 = event.y

    def on_button_release(self, event):
        self.mouse_active = False

        self.x1 = event.x
        self.y1 = event.y

        self.draw_rectangle()

    def on_mouse_move(self, event):
        if not self.mouse_active:
            return

        self.x1 = event.x
        self.y1 = event.y

        self.draw_rectangle()

def get_crop_coordinates(imageName):
    results = {'left': None, 'right': None, 'top': None, 'bottom': None}

    app = GetCropCoordinatesApp(imageName, results)
    app.mainloop()

    return results

def get_images(input_directory, side):
    for file in os.listdir(os.path.join(input_directory, side)):
        path = os.path.join(input_directory, side, file)
        if os.path.isfile(path) and not file.startswith('.'):
            yield path

def process_images(images, offset, rotate, crop):
    for i, image in enumerate(images):
        ext = os.path.splitext(image)[1]
        out = os.path.join('output', '%07d%s' % (i * 2 + offset, ext))
        args = [JPEGTRAN, '-copy', 'all', '-trim', '-crop', '%sx%s+%s+%s' % (crop['right'] - crop['left'], crop['bottom'] - crop['top'], crop['left'], crop['top']), '-outfile', out, image]
        print "Calling: %s" % ' '.join(args)
        subprocess.check_call(args)
        args = [JPEGTRAN, '-copy', 'all', '-trim', '-rotate', rotate, '-outfile', out, out]
        print "Calling: %s" % ' '.join(args)
        subprocess.check_call(args)

left_images = []
right_images = []

for input_directory in sys.argv[1:]:
    left_images += get_images(input_directory, 'left')
    right_images += get_images(input_directory, 'right')

if len(left_images) != len(right_images):
    print "Number of left images (%s) does not match right images (%s)" % (len(left_images), len(right_images))
    sys.exit(1)

if len(left_images) == 0:
    print "No images"
    sys.exit(2)

if os.path.exists('output'):
    print "Output directory already exists"
    sys.exit(3)

print "Processing left images: %s" % ', '.join(left_images)
print "Processing right images: %s" % ', '.join(right_images)

left_crop = get_crop_coordinates(left_images[0])

for c in left_crop.values():
    if c is None:
        print "No crop coordinates"
        sys.exit(4)

right_crop = get_crop_coordinates(right_images[0])

for c in right_crop.values():
    if c is None:
        print "No crop coordinates"
        sys.exit(4)

if os.path.exists('output'):
    print "Output directory already exists"
    sys.exit(3)

os.mkdir('output')

process_images(left_images, 0, '90', left_crop)
process_images(right_images, 1, '270', right_crop)
