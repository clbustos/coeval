def dataframe(worksheet)
  header=nil
  df=[]
  converter=nil
  worksheet.each do   |row|
    unless header
      header=row.cells.map {|v| v.value}
      converter=lambda {|row|
        h={}
        row.cells.each_with_index {|el,index|
          h[header[index]]=el.value
        }
        h
      }
    else
      df.push(converter.call(row))
    end

  end
  df
end
