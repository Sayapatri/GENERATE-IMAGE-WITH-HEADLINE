from PIL import Image, ImageDraw, ImageFont
import os
from flask import Flask, request, send_file, render_template

app = Flask(__name__)

# Directory for generated images
OUTPUT_DIR = "generated_images"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def wrap_text(text, font, max_width):
    """Wraps text into multiple lines to fit within a specified width."""
    lines = []
    words = text.split()
    current_line = ""

    for word in words:
        test_line = f"{current_line} {word}".strip()
        text_width = font.getbbox(test_line)[2]  # Calculate text width
        if text_width <= max_width:
            current_line = test_line
        else:
            lines.append(current_line)
            current_line = word
    if current_line:
        lines.append(current_line)

    return lines

def process_and_add_headline(input_image_path, logo_path, headline, output_path):
    """Processes the input image, adds a headline and logo, and saves it."""
    # Open the input image
    image = Image.open(input_image_path)

    # Resize the image to 800x600 while maintaining aspect ratio
    image = image.resize((800, 600))

    # Ensure the image has an RGB mode (necessary for JPEG conversion)
    if image.mode != "RGB":
        image = image.convert("RGB")

    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("arialbd.ttf", 40)
    max_width = image.width - 40  # Allow padding on the sides

    # Wrap the text into multiple lines
    wrapped_lines = wrap_text(headline, font, max_width)

    # Calculate the total height of the text
    total_text_height = sum(font.getbbox(line)[3] for line in wrapped_lines) + (len(wrapped_lines) - 1) * 10
    start_y = image.height - total_text_height - 20  # Position from the bottom with padding

    # Draw each line of text
    for line in wrapped_lines:
        text_width, text_height = font.getbbox(line)[2], font.getbbox(line)[3]
        text_position = ((image.width - text_width) // 2, start_y)
        draw.text(text_position, line, fill="yellow", font=font)
        start_y += text_height + 10  # Add line spacing

    # Add the logo to the top-right corner
    if logo_path:
        logo = Image.open(logo_path).convert("RGBA")
        logo_width, logo_height = logo.size

        # Resize the logo to fit into a smaller area if necessary
        max_logo_size = 100  # Maximum width or height
        if max(logo_width, logo_height) > max_logo_size:
            scale = max_logo_size / max(logo_width, logo_height)
            logo = logo.resize((int(logo_width * scale), int(logo_height * scale)), Image.Resampling.LANCZOS)


        # Place the logo in the top-right corner
        logo_position = (image.width - logo.width - 10, 10)  # Padding of 10 pixels
        image.paste(logo, logo_position, logo)  # Use the logo as a mask for transparency

    # Save the output image
    image.save(output_path, format="JPEG")

@app.route('/')
def index():
    """Render the frontend page."""
    return render_template('index.html')

@app.route('/generate', methods=['POST'])
def generate_image():
    """API endpoint to upload an image, process it, and generate output."""
    # Get headline from query parameters
    headline = request.form.get('headline', 'Breaking News!')

    # Get uploaded image
    if 'image' not in request.files:
        return "No image uploaded", 400

    input_image = request.files['image']
    input_path = os.path.join(OUTPUT_DIR, input_image.filename)
    input_image.save(input_path)

    # Get uploaded logo (optional)
    logo_path = None
    if 'logo' in request.files and request.files['logo'].filename != '':
        logo = request.files['logo']
        logo_path = os.path.join(OUTPUT_DIR, logo.filename)
        logo.save(logo_path)

    # Define output path
    output_path = os.path.join(OUTPUT_DIR, f"{headline[:10]}.jpg")

    # Process the image
    process_and_add_headline(input_path, logo_path, headline, output_path)

    # Serve the processed image
    return send_file(output_path, mimetype='image/jpeg')

if __name__ == '__main__':
    app.run(debug=True)
