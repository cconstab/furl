#!/usr/bin/env python3
"""
Convert the existing app_icon.svg to PNG format for use as launcher icon
"""

try:
    from PIL import Image, ImageDraw
    import os
    import xml.etree.ElementTree as ET
    
    # Read the SVG file
    svg_path = "assets/icons/app_icon.svg"
    if not os.path.exists(svg_path):
        print(f"❌ SVG file not found: {svg_path}")
        exit(1)
    
    # Since we don't have SVG rendering library, let's recreate the design based on the SVG
    size = 1024
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Background circle with gradient (purple to violet)
    center = size // 2
    radius = int(240 * size / 512)  # Scale from 512 to our size
    
    # Create gradient effect by drawing concentric circles
    for i in range(radius):
        # Gradient from #4f46e5 (79, 70, 229) to #7c3aed (124, 58, 237)
        factor = i / radius
        r = int(79 * (1 - factor) + 124 * factor)
        g = int(70 * (1 - factor) + 58 * factor)
        b = int(229 * (1 - factor) + 237 * factor)
        
        draw.ellipse([center - radius + i, center - radius + i, 
                     center + radius - i, center + radius - i], 
                    fill=(r, g, b, 255))
    
    # Scale factors
    scale = size / 512
    
    # Document/File icon (white with gradient effect)
    doc_left = int(180 * scale)
    doc_top = int(120 * scale)
    doc_right = int(380 * scale)
    doc_bottom = int(392 * scale)
    doc_corner = int(332 * scale)
    doc_corner_bottom = int(168 * scale)
    
    # Main document rectangle
    draw.rectangle([doc_left, doc_top, doc_right, doc_bottom], 
                  fill=(255, 255, 255, 255))
    
    # Corner fold triangle
    corner_points = [
        (doc_corner, doc_top),
        (doc_corner, doc_corner_bottom),
        (doc_right, doc_corner_bottom)
    ]
    draw.polygon(corner_points, fill=(199, 210, 254, 255))  # #c7d2fe
    
    # Chain link elements (representing URL sharing)
    chain_x = int(200 * scale)
    chain_y = int(220 * scale)
    
    # First link (ellipse rotated)
    link1_x = chain_x + int(30 * scale)
    link1_y = chain_y + int(25 * scale)
    link_rx = int(15 * scale)
    link_ry = int(25 * scale)
    
    # Draw elliptical links as rounded rectangles (approximation)
    link_width = 8 * scale
    
    # First link
    draw.ellipse([link1_x - link_rx, link1_y - link_ry, 
                 link1_x + link_rx, link1_y + link_ry], 
                outline=(79, 70, 229, 255), width=int(link_width))
    
    # Second link
    link2_x = chain_x + int(65 * scale)
    link2_y = chain_y + int(60 * scale)
    draw.ellipse([link2_x - link_rx, link2_y - link_ry, 
                 link2_x + link_rx, link2_y + link_ry], 
                outline=(79, 70, 229, 255), width=int(link_width))
    
    # Connection line between links
    conn_x1 = chain_x + int(42 * scale)
    conn_y1 = chain_y + int(37 * scale)
    conn_x2 = chain_x + int(53 * scale)
    conn_y2 = chain_y + int(48 * scale)
    draw.line([conn_x1, conn_y1, conn_x2, conn_y2], 
              fill=(79, 70, 229, 255), width=int(link_width))
    
    # Decorative dots
    dot_color = (199, 210, 254, 255)  # #c7d2fe
    
    dot1_x = int(320 * scale)
    dot1_y = int(300 * scale)
    dot1_r = int(4 * scale)
    draw.ellipse([dot1_x - dot1_r, dot1_y - dot1_r, 
                 dot1_x + dot1_r, dot1_y + dot1_r], fill=dot_color)
    
    dot2_x = int(340 * scale)
    dot2_y = int(280 * scale)
    dot2_r = int(3 * scale)
    draw.ellipse([dot2_x - dot2_r, dot2_y - dot2_r, 
                 dot2_x + dot2_r, dot2_y + dot2_r], fill=dot_color)
    
    dot3_x = int(350 * scale)
    dot3_y = int(320 * scale)
    dot3_r = int(3 * scale)
    draw.ellipse([dot3_x - dot3_r, dot3_y - dot3_r, 
                 dot3_x + dot3_r, dot3_y + dot3_r], fill=dot_color)
    
    # Save the PNG version
    output_path = "assets/icons/app_icon.png"
    image.save(output_path, "PNG")
    
    print(f"✅ Converted SVG to PNG: {output_path}")
    print(f"📐 Size: {size}x{size} pixels")
    print(f"🎨 Design: Purple gradient background, document with chain links")
    print(f"🔗 Theme: File sharing and URL generation")
    
except ImportError:
    print("❌ PIL (Pillow) not available")
except Exception as e:
    print(f"❌ Error: {e}")
