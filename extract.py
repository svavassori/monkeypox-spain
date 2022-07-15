# This script extracts the dates of Monkeypox onset chart from the given PNG file
# passed as parameter and writes them to stdout in a CSV format (date and cases).

from datetime import datetime, timedelta
from math import trunc
import sys
from PIL import Image
from typing import Final

BLACK: Final[int] = 0
GRAY:  Final[int] = 103
WHITE: Final[int] = 255

def median_square_size(square_list):
    square_sizes = [ x2 - x1 for (x1, x2) in square_list ]
    square_sizes.sort()
    return square_sizes[int(len(square_sizes) / 2)]

def extract(filename):
    with Image.open(filename) as im:
        im = im.convert("L")
        x_axis = find_X_axis(im)
        x_left, x_right = find_X_bounds(im, x_axis)
        # end values are excluded
        im_cropped = im.crop((x_left, 0, x_right + 1, x_axis + 1))
        maxX, maxY = im_cropped.size
        squares = parse_alined_squares(im_cropped, range(maxX), maxY - 2, lambda x, y: (x, y))
        square_size = median_square_size(squares)
        squares = fill_with_white_squares(squares, square_size)
        values = count_values(squares, im_cropped, square_size)
        bins = to_days(values)
        print_bins_as_csv(bins)

def find_X_axis(image):
    _, maxY = image.size
    for y in range(maxY - 1, -1, -1):
        line_is_black = True
        for x in range(100, 200):
            color = image.getpixel((x, y))
            if (color != BLACK):
                line_is_black = False
                break
        if line_is_black:
            return y
    raise Exception("Unable to find black line in image")

def find_X_bounds(image, maxY):
    maxX, _ = image.size
    y = maxY - 1
    # widen by 1 pixel for the border around
    x_left = find_gray(image, range(maxX), y) - 1
    x_right = find_gray(image, reversed(range(maxX)), y) + 1
    return x_left, x_right

def find_gray(image, rang, y):
    for x in rang:
        color = image.getpixel((x, y))
        if (color == GRAY):
            return x

def parse_alined_squares(image, outer_range, line, to_tuple, square_size = 11):
    # square_size default value is based on observation, needed to uniform
    # horizontal scan and vertical.
    previous = WHITE
    startX = 0
    squares = []
    for x in outer_range:
        color = image.getpixel(to_tuple(x, line))
        white_distance = WHITE - color
        gray_distance = abs(GRAY - color)
        if (gray_distance < white_distance):
            if (previous == WHITE):
                # start of the square
                startX = x
                previous = GRAY
        elif (previous == GRAY):
            # end of a square
            # detect multiple squares packed together
            previous = WHITE
            (x1, x2) = to_tuple(startX, x)
            n_squares = round((x2 - x1) / square_size)
            for n in range(n_squares):
                xt = x1 + square_size
                squares.append((x1, xt))
                x2 = xt
    return squares

def fill_with_white_squares(squares, square_size):
    filled = []
    x_left = 0
    for (x0, x1) in squares:
        n_white_squares = trunc((x0 - x_left) / square_size)
        for n in range(n_white_squares):
            x_right = x_left + square_size
            filled.append((x_left, x_right))
            x_left = x_right
        x_left = x1
        filled.append((x0, x1))
    return filled

def count_values(squares, image, square_size):
    _, maxY = image.size
    values = []
    for (x1, x2) in squares:
        line = round((x2 + x1) / 2)
        column = parse_alined_squares(image, reversed(range(maxY - 1)), line, lambda x, y: (y, x), square_size)
        values.append(len(column))
    return values

def to_days(values):
    # first two non-zero value are at April 26 and 27, then there is April "31" to skip...
    days = []
    for i in range(5):
        days.append((datetime(2022, 4, i + 26), values[i]))
    current = datetime(2022, 5, 1)
    for value in values[6:]:
        days.append((current, value))
        current += timedelta(days=1)
    return days


def print_bins_as_csv(bins):
    print("date,cases")
    for date, value in bins:
        print(date.strftime("%Y-%m-%d"), value, sep=",")

def main():
    if len(sys.argv) == 2:
        extract(sys.argv[1])
    else:
        sys.exit("Usage: python3 " + sys.argv[0] + " input_file.png")

if __name__ == "__main__":
    main()
