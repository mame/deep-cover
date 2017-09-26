### Case with evaluated
    case 1
    when 0
      "not here"
#>X
    when 1
      "here"
    when 2
#>X
      "not here"
#>X
    end

#### Without entering when
    case 1
    when 0
      "not here"
#>X
    end

#### With raise in case evaluated
    case [1, raise, "not here"]
#>  xxxx            xxxxxxxxxx
    when 0
#>X
      "not here"
#>X
    end
#>X

#### With raise in when condition
    case 1
    when 0
      "not here"
#>X
    when raise
#>  xxxx
      "not here"
#>X
    when 1
#>X
      "not here"
#>X
    end

#### with raise in when body
    case 1
    when 0
      "not here"
#>X
    when 1
      raise
      "not here"
#>X
    when 2
#>X
      "not here"
#>X
    end

#### with multi part when condition
    case 1
    when 0, 10, 20
      "not here"
#>X
    when -1, 1, 1000
#>              xxxx
      "here"
    when -2, 2, 2000
#>X
      "not here"
#>X
    end

#### with raise in multi part when condition
    case 1
    when 0, 10, 20
      "not here"
#>X
    when -1, raise, 1000
#>                  xxxx
      "not here"
#>X
    when -2, 2, 2000
#>X
      "not here"
#>X
    end


### Case with evaluated and else
    case 1
    when 0
      "not here"
#>X
    when 1
      "here"
    when 2
#>X
      "not here"
#>X
    end

#### Without entering when
    case 1
    when 0
      "not here"
#>X
    else
      "here"
    end

#### With raise in case evaluated
    case [1, raise, "not here"]
#>  xxxx            xxxxxxxxxx
    when 0
#>X
      "not here"
#>X
    else
#>X
      "not here"
#>X
    end
#>X

#### With raise in when condition
    case 1
    when 0
      "not here"
#>X
    when raise
#>  xxxx
      "not here"
#>X
    when 1
#>X
      "not here"
#>X
    else
#>X
      "not here"
#>X
    end

#### with raise in when body
    case 1
    when 0
      "not here"
#>X
    when 1
      raise
      "not here"
#>X
    when 2
#>X
      "not here"
#>X
    else
#>X
      "not here"
#>X
    end

#### with raise in else body
    case 1
    when 0
      "not here"
#>X
    when 2
      "not here"
#>X
    else
      raise
      "not here"
#>X
    end

### With failed ===
    obj = Object.new
    obj.define_singleton_method(:===) do |other|
      raise
    end

    case 1
    when obj, 1
#>            x
      "not here"
#>X
    end
