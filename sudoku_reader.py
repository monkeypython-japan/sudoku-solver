from PIL import Image

import argparse 
import cv2
import json
import numpy as np
import os
import pyocr
import re
import shutil


class SUDOKU():

    __output_dir_path = "./result/"
    __param_json_path = "./param.json"

    __cell_per_line = 9 # Number of cell pre. 1 line.

    __cut_area_rate      = 0.001 # * 100[%] Ignore box size rate (Proportion of original image size) 
    __sudoku_area_margin = 0.01  # * 100[%] Sudoku box around margin rate
    __cell_min_size_reta = 1/111 # * 100[%] Cell min box size rate (Proportion of original image size)
    __cell_max_size_rate = 1/71  # * 100[%] Cell max box size rate (Proportion of original image size)
    __cell_threshold_value = 80  #  

    @staticmethod
    def create_output_dir():
        if os.path.exists(SUDOKU.__output_dir_path):
            shutil.rmtree(SUDOKU.__output_dir_path)
        os.mkdir(SUDOKU.__output_dir_path)

    @staticmethod
    def attach_output_dir(name):
        return os.path.join(SUDOKU.__output_dir_path, name)

    @staticmethod
    def read_param_json():
        with open(SUDOKU.__param_json_path) as j:
            params = json.load(j)
        
        SUDOKU.__cut_area_rate        = params["cut_area_rate"]
        SUDOKU.__sudoku_area_margin   = params["sudoku_area_margin"]
        SUDOKU.__sudoku_area_margin   = params["sudoku_area_margin"]
        SUDOKU.__cell_min_size_reta   = params["cell_min_size_reta"]
        SUDOKU.__cell_max_size_rate   = params["cell_max_size_rate"]
        SUDOKU.__cell_threshold_value = params["cell_threshold_value"]


    def __init__(self, debug_flg, json_flg):
        self.origin_fig = ""
        self.debug_flg  = debug_flg

        # Sudoku Field data
        self.sudoku_area = 0
        self.sudoku_area_edge =[]
        self.all_rects = []
        self.sudoku_cells = []

        # OCR
        tool_list = pyocr.get_available_tools()
        self.ocr_tool = tool_list[0]
        self.ocr_build = pyocr.builders.DigitBuilder(tesseract_layout=10)
        self.ocr_build_fallbacks = [
            pyocr.builders.DigitBuilder(tesseract_layout=8),
            pyocr.builders.DigitBuilder(tesseract_layout=6),
        ]

        # Result
        self.sudoku_prob = np.zeros((SUDOKU.__cell_per_line, SUDOKU.__cell_per_line))

        if self.debug_flg:
            SUDOKU.create_output_dir()

        if json_flg:
            SUDOKU.read_param_json()

    # Import image
    def read_fig(self, fig_path):
        # Figure
        self.origin_fig = cv2.imread(fig_path)
        self.gray_fig   = cv2.cvtColor(self.origin_fig, cv2.COLOR_BGR2GRAY)

        # Figure size and area
        self.origin_fig_height = self.origin_fig.shape[0]
        self.origin_fig_width  = self.origin_fig.shape[1]
        self.origin_fig_area   = self.origin_fig_width * self.origin_fig_width

    # Pre-proc. for OCR 
    def serch_rects(self):
        self.gray_fig =cv2.GaussianBlur(self.gray_fig, (3, 3), sigmaX=4)
        edges = cv2.Canny(self.gray_fig, 1, 100, apertureSize=3)
        cv2.imwrite(SUDOKU.attach_output_dir('edges.png'), edges)

        # 膨張処理
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        edges  = cv2.dilate(edges, kernel)

        # 輪郭抽出
        contours, hierarchy = cv2.findContours(edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

        # 面積でフィルタリング
        rects = []
        target_rect_area = 0
        target_rect = []
        for cnt, hrchy in zip(contours, hierarchy[0]):
            rect_area = cv2.contourArea(cnt)
            if rect_area > SUDOKU.__cut_area_rate * self.origin_fig_area:
                rect = cv2.minAreaRect(cnt)
                rect_points = cv2.boxPoints(rect).astype(int)
                # 盤面全体（最大輪郭）はルートノードも含めて探す
                if target_rect_area < rect_area:
                    target_rect_area = rect_area
                    target_rect = rect_points
                # セル候補はルートノードを除く
                if hrchy[3] != -1:
                    rects.append(rect_points)
        
        margin_rate   =  SUDOKU.__sudoku_area_margin
        tr_left   = int(min(target_rect[:,0]))
        tr_right  = int(max(target_rect[:,0]))
        tr_top    = int(min(target_rect[:,1]))
        tr_bottom = int(max(target_rect[:,1]))
        margin_width  = (tr_right - tr_left)  * margin_rate
        margin_height = (tr_bottom - tr_top) * margin_rate

        rects = [rect for rect in rects if (min(rect[:,0]) > tr_left   - margin_width)  and\
                                           (max(rect[:,0]) < tr_right  + margin_width)  and\
                                           (min(rect[:,1]) > tr_top    - margin_height) and\
                                           (max(rect[:,1]) < tr_bottom + margin_height)]

        self.all_rects = rects
        self.sudoku_area_edge = target_rect
        self.sudoku_area = target_rect_area

    # Get vertexies pixel
    def get_rect_vertex(self, rect):
        shape_dict = {}
        shape_dict["left"]   = min(rect[:,0])
        shape_dict["right"]  = max(rect[:,0])
        shape_dict["top"]    = min(rect[:,1])
        shape_dict["bottom"] = max(rect[:,1])
        return shape_dict 

    # Calculate rect area
    def calc_rect_area(self, rect):
        rect_shape = self.get_rect_vertex(rect)
        return (rect_shape["right"] - rect_shape["left"]) *\
                 (rect_shape["bottom"] - rect_shape["top"])

    # Get rect width and height
    def get_rect_size(self, rect):
        rect_shape = self.get_rect_vertex(rect)
        w = (rect_shape["right"] - rect_shape["left"])
        h = (rect_shape["bottom"] - rect_shape["top"])
        return [w, h]

    #Return rect CoM
    def get_rect_COM(self, rect):
        rect_size = self.get_rect_size(rect)
        rect_edge = self.get_rect_vertex(rect)
        return [rect_edge["left"]+rect_size[0]/2, rect_edge["top"]+rect_size[1]/2]

    # Get and sort sudoku cells 
    def get_sudoku_cell(self):
        for rect in self.all_rects:
            rect_area = self.calc_rect_area(rect)
            #print(self.sudoku_area/90, rect_area)

            if (self.sudoku_area * SUDOKU.__cell_min_size_reta <= rect_area) and\
                 (rect_area <=self.sudoku_area * SUDOKU.__cell_max_size_rate):
                self.sudoku_cells.append(rect)

        col_size = self.get_rect_size(self.sudoku_area_edge)[0] / SUDOKU.__cell_per_line #  colnum width
        area_left = self.get_rect_vertex(self.sudoku_area_edge)["left"] 
        col_lines = [i * col_size + area_left for i in range(SUDOKU.__cell_per_line+1)]
        
        tmp_cell = []
        for i in range(SUDOKU.__cell_per_line):        
            col_cell =  [cell for cell in self.sudoku_cells\
                            if (col_lines[i] < self.get_rect_COM(cell)[0]) and\
                                (self.get_rect_COM(cell)[0] < col_lines[i+1])]
            col_cell = sorted(col_cell, key=lambda x: (x[0][1]))
            tmp_cell.extend(col_cell)
            
        self.sudoku_cells = tmp_cell

    # Read cell number with tesseract-OCR
    def read_cell_number(self, id):
        edge = self.get_rect_vertex(self.sudoku_cells[id])
        cell_size = self.get_rect_size(self.sudoku_cells[id])
        inside = (0.1 * np.array(cell_size)).astype("int")

        _, img_cv = cv2.threshold(self.gray_fig[edge["top"]+inside[1]:edge["bottom"]-inside[1],\
                                     edge["left"]+inside[0]:edge["right"]-inside[0]],\
                                    SUDOKU.__cell_threshold_value, 255, cv2.THRESH_BINARY)
        img = cv2.GaussianBlur(img_cv, (3, 3), sigmaX=10)
        img = Image.fromarray(img_cv)
    
        txt = self.ocr_tool.image_to_string(img, lang="eng", builder=self.ocr_build)
        for fallback in self.ocr_build_fallbacks:
            if txt:
                break
            txt = self.ocr_tool.image_to_string(img, lang="eng", builder=fallback)

        if self.debug_flg: print(id, txt)

        for d in txt:
            #print(print, d)#d.content)
            if re.match("[0-9]{1}",d):#d.content):
                pos_x = id % SUDOKU.__cell_per_line
                pos_y = int(id / SUDOKU.__cell_per_line)
                self.sudoku_prob[pos_x, pos_y] = int(d)#d.content)

        if self.debug_flg:
            cv2.imwrite(SUDOKU.attach_output_dir("_img_{}.png".format(id)), img_cv)


    def draw_reacts(self):
        draw_list = self.sudoku_cells
        #draw_list = self.all_rects
        for i, rect in enumerate(draw_list):
            color = np.random.randint(0, 255, 3).tolist()
            cv2.drawContours(self.origin_fig, draw_list, i, color, 2)
            cv2.putText(self.origin_fig, str(i), tuple(rect[0]),
                             cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 3)

        cv2.imwrite(SUDOKU.attach_output_dir("result.png"), self.origin_fig)


if __name__ == "__main__":

    # Arguments 
    paser = argparse.ArgumentParser()
    paser.add_argument("fig_path", type=str, help="A sudoku image path.")
    paser.add_argument("-d", "--debug", action="store_true")
    paser.add_argument("-j", "--json", action="store_true")    
    
    args = paser.parse_args()

    try:
        test = SUDOKU(args.debug, args.json)
        test.read_fig(args.fig_path)

        test.serch_rects()
        test.get_sudoku_cell()
        for i, rect in enumerate(test.sudoku_cells):
            test.read_cell_number(i)

        if test.debug_flg:
            test.draw_reacts()

        print(test.sudoku_prob)
    
    except:
        import traceback
        print(traceback.format_exc())
        