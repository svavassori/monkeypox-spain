# This script extracts the dates of Monkeypox onset chart from the given svg file
# passed as parameter and writes them to stdout in a CSV format (date and cases).
#
# It expects only one chart with blue square (i.e. fill:#2f75b5;) to be present in the SVG file.
# It uses svgpathtools 1.5.1, so that dependency must be available.
#

from collections import namedtuple
from functools import reduce
from itertools import groupby
import sys
from typing import NamedTuple
from svgpathtools import svg2paths
from xml.dom.minidom import Node, parse

Bin=namedtuple("Bin", "date x delta")
Matrix=namedtuple("Matrix", "x y text")

def get_blue_paths(filename):
    paths, attributes = svg2paths(filename)
    blue_paths = []
    for index, attr in enumerate(attributes):
        style = attr.get("style", "")
        if "fill:#2f75b5;" in style:
            blue_paths.append(paths[index])
    return blue_paths

def paths_to_bin(path, bin_size):
    # width and height should be always >= 1 since the minimum is a single square.
    hline = path[0]
    vline = path[3]
    x = hline.start.real
    dh = hline.length()
    dv = vline.length()
    base_bin = int(x / bin_size)
    width = int(dh / bin_size)
    height = round(dv / bin_size) # sometimes is slightly less than a multiple of binSize
    return [ Bin(None, i, height) for i in range(base_bin, base_bin + width) ]

def find_blue_path_node(document):
    for node in document.getElementsByTagName("path"):
        if "fill:#2f75b5;" in node.getAttribute("style"):
            return node
    return None

def find_parent(node):
    stack = []
    while (node.nodeType != Node.DOCUMENT_NODE):
        stack.append(node)
        node = node.parentNode
    return stack[-3]

def extract_text_nodes(parent, ymin):
    text_nodes = filter(lambda d: "No incluidos" not in d.text,
                 filter(lambda d: (d.y < ymin),
                 map(parse_text_node, parent.getElementsByTagName("text"))))
    return splitter(text_nodes, lambda m: m.text.isnumeric())

def parse_text_node(node):
    fields = node.getAttribute("transform").removeprefix("matrix(").removesuffix(")").split(",")
    x = float(fields[-2])
    y = float(fields[-1])
    text = node.firstChild.firstChild.wholeText.strip()
    return Matrix(x=x, y=y, text=text)

def splitter(data, predicate):
    yes, no = [], []
    for d in data:
        if predicate(d):
            yes.append(d)
        else:
            no.append(d)
    return (yes, no)
        
def group_days(day_list):
    first_day_index = [ index for index, day in enumerate(day_list) if day.text == "1" ]
    first_day_index.append(len(day_list))
    grouped = []
    start_index = 0
    for i in first_day_index:
        grouped.append(day_list[start_index:i])
        start_index = i
    return grouped

def median_bin_size(day_list):
    bin_size = [ day_list[i].x - day_list[i - 1].x for i in range(1, len(day_list)) ]
    bin_size.sort()
    return bin_size[int(len(bin_size) / 2)]

# It is ridiculous that Python3 doesn't handles locales internally
# and it depends on the ones installed in the platform, WTF?
spanish_month_to_number = {
    "Enero":      "01",
    "Febrero":    "02",
    "Marzo":      "03",
    "Abril":      "04",
    "Mayo":       "05",
    "Junio":      "06",
    "Julio":      "07",
    "Agosto":     "08",
    "Septiembre": "09",
    "Octubre":    "10",
    "Noviembre":  "11",
    "Diciembre":  "12"
}

def bin_days(months, days_by_month, bin_size):
    days_binned = []
    for month_year, days_in_month in zip(months, days_by_month):
        (month, year) = month_year.split(" ")
        num_month = spanish_month_to_number[month]
        days_binned.extend(merge_days(days_in_month, num_month, year, bin_size))
    return days_binned

def merge_days(days_in_month, month, year, bin_size):
    day_binned = []
    for day in days_in_month:
        local_date = f"{year}-{month}-{day.text}"
        bin = int(day.x / bin_size)
        day_binned.append(Bin(local_date, bin, 0))
    return day_binned

def extract(filename):
    blue_paths = get_blue_paths(filename)
    ymin_squares = min(map(lambda p: p.start.imag, blue_paths))

    with parse(filename) as document:
        parent = find_parent(find_blue_path_node(document))
        (day_list, month_list) = extract_text_nodes(parent, ymin_squares)

    month_list.sort(key=lambda m: m.x)
    months = list(map(lambda m: m.text, month_list))
    days_by_month = group_days(day_list)
    # removes April 31: it doesn't exist
    days_by_month[0].pop()
    bin_size = median_bin_size(day_list)
    days_binned = bin_days(months, days_by_month, bin_size)
    for path in blue_paths:
        days_binned.extend(paths_to_bin(path, bin_size))

    bins = merge_bins_list(days_binned)
    print_bins_as_csv(bins)

def merge_bins_list(days_binned):
    by_x = lambda b: b.x
    days_binned.sort(key=by_x)
    return [ reduce(merge_bins, group) for _, group in groupby(days_binned, key=by_x) ]

def merge_bins(bin1, bin2):
    local_date = bin1.date if bin1.date is not None else bin2.date
    return Bin(local_date, bin1.x, bin1.delta + bin2.delta)

def print_bins_as_csv(bins):
    print("date,cases")
    for bin in bins:
        print(bin.date, bin.delta, sep=",")

def main():
    if len(sys.argv) == 2:
        extract(sys.argv[1])
    else:
        sys.exit("Usage: python3 " + sys.argv[0] + " input_file.svg")

if __name__ == "__main__":
    main()
