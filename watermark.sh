#!/bin/bash
if [ -z "$1" ]; then
  echo "No file count provided!"
  exit 1
fi

if [ ! -d "/storage/emulated/0/WatermarkProcess" ]; then
  mkdir /storage/emulated/0/WatermarkProcess
fi

images=$(ls -t *.jpg | head -n "$1")
amapapi="paste your key here" # 填写自己的高德地图API Key
for image in $images; do
  width=$(identify -format "%w" "$image")
  height=$(identify -format "%h" "$image")

  # 矩形面积设为原图的7.63%，宽高比5:2，像素取整
  area=$(echo "0.0763 * $width * $height" | bc -l)
  h=$(echo "sqrt(($area * 2)/5)" | bc -l)
  w=$(echo "$h * 5 / 2" | bc -l)
  h_rect=$(printf "%.0f" "$h")
  h_rect=$((h_rect < 1 ? 1 : h_rect))
  w_rect=$(printf "%.0f" "$w")
  w_rect=$((w_rect < 1 ? 1 : w_rect))

  # 文件参数，包含文件名，日期，输出路径，位置信息
  origname=$(echo "$image" | awk -F'/' '{print $NF}')
  custdate=$(identify -format %[exif:datetime] $image | awk -F: '{print $1"."$2"."$3":"$4":"$5}')
  output_path="/storage/emulated/0/WatermarkProcess/$origname"
  gpsinfo=$(
    exiftool -n -GPSLongitude -GPSLatitude -s -s -s "$image" | awk '
  NR==1 { lon = $1 }          # 读取第一行（经度）
  NR==2 { lat = $1 }          # 读取第二行（纬度）
  END {
    print sprintf("%f,%f", lon, lat)
  }'
  )
  #WGS-84转换为GCJ-20，调用高德API
  gcjinfo=$(curl -s "https://restapi.amap.com/v3/assistant/coordinate/convert?locations=$gpsinfo&coordsys=gps&output=xml&key=$amapapi" | xmllint --xpath 'string(/response/locations)' -)
  gcjdisplay=$(echo "$gcjinfo" | awk -F ',' '
  { 
    lon=$1; lat=$2
  }
  END {
    lon_abs = (lon < 0) ? -lon : lon
    lon_dir = (lon < 0) ? "W" : "E"
    lat_abs = (lat < 0) ? -lat : lat
    lat_dir = (lat < 0) ? "S" : "N"
    printf "%.4f°%s,%.4f°%s\n", lon_abs, lon_dir, lat_abs, lat_dir
  }')
  lon_str=$(echo "$gcjdisplay" | cut -d ',' -f 1)
  lat_str=$(echo "$gcjdisplay" | cut -d ',' -f 2)

  #高德地图逆地理编码API获取建筑信息
  location=$(curl -s "https://restapi.amap.com/v3/geocode/regeo?output=xml&location=$gcjinfo&key=$amapapi&radius=1000&extensions=all" | xmllint --xpath 'string(/response/regeocode/pois/poi[1]/name)' -)

  # 文本参数，字体大小，边距等
  author="ZTE CCN RSC" #这里可以根据自己的喜好进行修改
  font_size=$(echo "$h_rect / 8" | bc -l | awk '{print int($1+0.5)}')
  font_size=$((font_size < 12 ? 12 : font_size))                           # 最小字号为12
  left_margin=$(echo "$w_rect * 0.05" | bc -l | awk '{print int($1+0.5)}')
  text_content="经度: $lon_str\n纬度: $lat_str\n地点: $location\n时间: $custdate"
  # 计算行间距
  line_spacing=$(echo "$font_size * 0.2" | bc -l | awk '{print int($1+0.5)}') # 行数+1=5个间隔

  # ImageMagick合成水印，文本自动垂直居中
  magick "$image" \
    \( -size "${w_rect}x${h_rect}" \
    xc:"rgba(0,0,0,0.5)" \
    -fill white \
    -font "Noto-Sans-CJK-SC" \
    -pointsize $font_size \
    -interline-spacing $line_spacing \
    -gravity west \
    -annotate +${left_margin}+0 "$text_content" \) \
    -gravity southwest \
    -geometry +0+0 \
    -composite \
    \( -background none \
    -fill white \
    -font "Noto-Sans-CJK-SC" \
    -pointsize $font_size \
    -gravity east \
    label:"$author" \
    -trim +repage \) \
    -gravity southeast \
    -geometry +${left_margin}+${left_margin} \
    -composite \
    "$output_path"

  #通知系统触发文件更新，没有root权限需要注释掉
  #su -c am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///storage/emulated/0/WatermarkProcess/$origname
  echo "Done."
done
