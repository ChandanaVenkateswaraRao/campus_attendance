from PIL import Image
import sys

def remove_background(input_path, output_path, tolerance=30):
    try:
        img = Image.open(input_path).convert("RGBA")
        datas = img.getdata()

        # Assuming top-left pixel is the background color
        bg_color = datas[0]
        
        new_data = []
        for item in datas:
            # Check if pixel is within tolerance of background color
            if (abs(item[0] - bg_color[0]) <= tolerance and
                abs(item[1] - bg_color[1]) <= tolerance and
                abs(item[2] - bg_color[2]) <= tolerance):
                # Make transparent
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)

        img.putdata(new_data)
        img.save(output_path, "PNG")
        print("Successfully made background transparent")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    remove_background("assets/images/logo_new.png", "assets/images/logo.png")
