from PIL import Image, ImageDraw

def clean():
    try:
        img = Image.open('assets/images/invoice_template_blank.png')
        if img.mode != 'RGB':
            img = img.convert('RGB')
        draw = ImageDraw.Draw(img)

        # Scale factor from PDF points (595x842) to Image pixels (2481x3508)
        scale_x = 2481 / 595.0
        scale_y = 3508 / 842.0

        def scrub(x1, y1, x2, y2):
            # Inflate a little bit to ensure coverage
            px1 = int(x1 * scale_x) - 4
            py1 = int(y1 * scale_y) - 4
            px2 = int(x2 * scale_x) + 4
            py2 = int(y2 * scale_y) + 4
            draw.rectangle([px1, py1, px2, py2], fill=(255, 255, 255))

        # SCRUB HEADER VALUES
        scrub(80, 103, 140, 120)    # Bill No "1948"
        scrub(65, 120, 300, 137)    # Customer Name "Vijayalashmi..."
        scrub(425, 120, 530, 137)   # Phone ID "9444391219"
        scrub(65, 137, 250, 155)    # Site "Neelaangari"
        scrub(430, 195, 520, 215)   # Date "09-02-25"
        
        # We also have a random 'PD' scribbled near the Driver label
        scrub(100, 195, 150, 215)   

        # SCRUB RIGHT MATRIX ITEMS and AMOUNTS
        # The original image had items written in the center-right empty space.
        # We wipe the entire bounding box where those items were.
        # X: 247 (just inside center line) to 522 (just inside totals line)
        # Y: 260 (just below 'Our items:' or whatever) to 360 (just above the totals)
        scrub(247, 250, 522, 360)

        # SCRUB RIGHT TOTALS BOX
        # The totals column had old numbers.
        # X: 527 to 578
        # Y: 350 to 455
        scrub(527, 350, 578, 455)

        # SCRUB LEFT MATRIX QUANTITIES ONLY (leaving matrix lines intact)
        # We have a printed table on the left. We just want to erase the typed numbers under the lines.
        # Left column of numbers (under 12 Palagai): X=110 to 135. Y=265 to 370
        scrub(110, 265, 135, 370)
        # Middle column (9 Palagai): X=175 to 200, Y=265 to 370
        scrub(172, 265, 205, 370)
        # Right column (6 Palagai): X=45 to 80, Y=265 to 290
        scrub(40, 265, 80, 290)
        # Far right column (Runner): X=235 to 260 (actually this is past the divider maybe?)
        scrub(220, 265, 243, 300)

        # Finally, bottom left had a dark "Joint Piece -" and a signature line maybe. We can erase just the value area
        scrub(70, 360, 95, 380) # The totals subbox left 1
        scrub(130, 370, 160, 395) # The totals subbox left 2
        scrub(10, 280, 40, 310) # The totals subbox left 3

        img.save('assets/images/invoice_template_blank.png')
        print('Blanked template successfully with pixel-accurate scale!')
        
    except Exception as e:
        print('Error:', e)

if __name__ == '__main__':
    clean()
