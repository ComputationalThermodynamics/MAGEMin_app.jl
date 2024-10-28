export init_AMR, select_cells_to_split_and_keep, perform_AMR, retrieve_ncells_c

"""
    AMR_data
"""
mutable struct AMR_data
    cells           :: Vector{Vector{Int64}}
    ncells          :: Vector{Vector{Int64}}
    points          :: Vector{Vector{Float64}}
    npoints         :: Vector{Vector{Float64}}
    hash_map        :: Dict{Vector{Float64}, Int}
    bnd_cells       :: Vector{Tuple}
    split_cell_list :: Vector{Int64}
    keep_cell_list  :: Vector{Int64}
    Xrange          :: Vector{Float64}
    Yrange          :: Vector{Float64}
end

"""
    compute_index(value, min_value, delta)
"""
function compute_index(value, min_value, delta)
    return Int64(round((value - min_value + delta) / delta))
end

"""
    compute_hash_map(data)
"""
function init_AMR(Xrange,Yrange,igs)

    nc_per_dim      = 2^igs              #number of cells per dimension
    np_per_dim      = nc_per_dim+1       #number of points per dimension

    points          = Vector{Vector{Float64}}(undef, 0)
    cells           = Vector{Vector{Int64}}(undef, 0)
    npoints         = Vector{Vector{Float64}}(undef, 0)
    ncells          = Vector{Vector{Int64}}(undef, 0)
    hash_map        = Dict{Vector{Float64}, Int}()
    bnd_cells       = Vector{Tuple}(undef, 0)
    split_cell_list = Vector{Int64}(undef, 0)
    keep_cell_list  = Vector{Int64}(undef, 0)

    # initialize rectinilinear grid
    for j in 1:np_per_dim
        for i in 1:np_per_dim
            push!(points, [(j-1)*(Xrange[2]-Xrange[1])/(np_per_dim-1) + Xrange[1], (i-1)*(Yrange[2]-Yrange[1])/(np_per_dim-1) + Yrange[1]])
        end
    end
    for j in 1:nc_per_dim
        for i in 1:nc_per_dim
            push!(cells, [i+(j-1)*np_per_dim, i+1+(j-1)*np_per_dim, i+1+j*np_per_dim, i+j*np_per_dim])
        end
    end

    data = AMR_data(    cells,
                        ncells,
                        points,
                        npoints,
                        hash_map,
                        bnd_cells,
                        split_cell_list,
                        keep_cell_list,
                        [Xrange[1],Xrange[2]],[Yrange[1],Yrange[2]])
    return data
end

""" 
    all_identical(arr::Vector{UInt64})
"""
function all_identical(arr::Vector{UInt64})
    return all(x -> x == arr[1], arr)
end


""" 
    select_cells_to_split_and_keep(data)
"""
function select_cells_to_split_and_keep(data)
    kp                      = length(data.keep_cell_list)
    data.split_cell_list    = []
    data.keep_cell_list     = []
    tot                     = length(data.cells)

    for i=1:kp
        tmp0 = Vector{UInt64}(undef, 0)
        for j=1:4
            tmp0 = push!(tmp0,Hash_XY[data.cells[i][j]])
        end
        nb = length(data.bnd_cells[i])
        if nb > 1
            for j=2:nb
                tmp0 = push!(tmp0,Hash_XY[data.bnd_cells[i][j]])
            end
        end
        if all_identical(tmp0)
            push!(data.keep_cell_list, i)
        else
            push!(data.split_cell_list, i)
        end

    end

    tmp = Vector{UInt64}(undef, 4)
    for i=kp+1:tot
        for j=1:4
            tmp[j] = Hash_XY[data.cells[i][j]]
        end

        if all_identical(tmp)
            push!(data.keep_cell_list, i)
        else
            push!(data.split_cell_list, i)
        end
    end

    return data
end

"""
    perform_AMR(data)
"""
function perform_AMR(data)
    npoints         = Vector{Vector{Float64}}(undef, 0)
    ncells          = Vector{Vector{Int64}}(undef, 0)

    tp              = length(data.points)
    ns              = length(data.split_cell_list)
    for i=1:ns

        tmp     = data.points[data.cells[data.split_cell_list[i]][1]]/2.0 + data.points[data.cells[data.split_cell_list[i]][3]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        c       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][1]]/2.0 + data.points[data.cells[data.split_cell_list[i]][2]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        w       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][2]]/2.0 + data.points[data.cells[data.split_cell_list[i]][3]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        n       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][3]]/2.0 + data.points[data.cells[data.split_cell_list[i]][4]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        e       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][4]]/2.0 + data.points[data.cells[data.split_cell_list[i]][1]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        s       = p;

        push!(ncells, [data.cells[data.split_cell_list[i]][1], w, c, s])
        push!(ncells, [w, data.cells[data.split_cell_list[i]][2], n, c])
        push!(ncells, [c, n, data.cells[data.split_cell_list[i]][3], e])
        push!(ncells, [s, c, e, data.cells[data.split_cell_list[i]][4]])
    end

    data.points     = vcat(data.points, npoints)

    data.bnd_cells  = Vector{Tuple}(undef, 0)
    nk              = length(data.keep_cell_list) 
    ix = [1 2; 2 3; 3 4; 4 1]
    for i=1:nk
        tmp_bnd = (i,)
        for k = 1:4
            tmp = data.points[data.cells[data.keep_cell_list[i]][ix[k,1]]]/2.0 + data.points[data.cells[data.keep_cell_list[i]][ix[k,2]]]/2.0
            if haskey(data.hash_map, tmp)
                p        = data.hash_map[tmp]
                tmp_bnd = (tmp_bnd...,p)
            end
        end

        push!(data.bnd_cells,tmp_bnd)

    end

    data.cells = vcat(data.cells[data.keep_cell_list], ncells)

    data.ncells     = ncells
    data.npoints    = npoints

    return data
end

"""
    retrieve_ncells_c(data)
"""
function retrieve_ncells_c(data)
    ncells_c        = Vector{Vector{Float64}}(undef, 0)
    split_cell_list = []
    keep_cell_list  = []

    for i=1:length(data.cells)
        tmp = zeros(UInt64,4)
        for j=1:4
            tmp[j] = Hash_XY[data.cells[i][j]]
        end
        if all_identical(tmp)
            push!(keep_cell_list, i)
        else
            push!(split_cell_list, i)
        end
    end

    ns              = length(split_cell_list)
    for i=1:ns
        tmp     = data.points[data.cells[split_cell_list[i]][1]]/2.0 + data.points[data.cells[split_cell_list[i]][3]]/2.0
        push!(ncells_c, tmp)
    end

    return ncells_c
end