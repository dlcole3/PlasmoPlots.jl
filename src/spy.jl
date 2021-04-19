rectangle(w, h, x, y) = Plots.Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])

"""
    Plots.spy(graph::OptiGraph;node_labels = false,labelsize = 24,subgraph_colors = false,node_colors = false,markersize = 1)

Plot a matrix visualization of the optigraph: `graph`. The following keyword arguments can be provided to customize the matrix visual.

* `node_labels = false`: whether to label nodes using the corresponding optinode label attribute.
* `labelsize`: the size for each node label.  Only active if `node_labels = true`.
* `subgraph_colors = false`: whether to color nodes according to their subgraph.
* `node_colors = false`: whether to color nodes.  Only active if `subgraph_colors = false`.
* `markersize = 1`: Size of the linking constraints in the matrix representation.
"""
function Plots.spy(graph::OptiGraph;node_labels = false,labelsize = 24,subgraph_colors = false,node_colors = false,markersize = 1)

    n_graphs = length(graph.subgraphs)
    if subgraph_colors
        cols = Colors.distinguishable_colors(n_graphs + 1)
        if cols[1] == Colors.colorant"black"
            cols[1] = Colors.colorant"grey"
        end
        colors = cols[2:end]
    else
        colors = [Colors.colorant"grey" for _= 1:n_graphs]
    end

    if node_colors
        cols = Colors.distinguishable_colors(length(all_nodes(graph)) + 1)
        if cols[1] == Colors.parse(Colorant,"black")
            cols[1] = Colors.parse(Colorant,"grey")
        end
        node_cols = cols[2:end]
    end


    #Plot limits
    n_vars_total = num_all_variables(graph)
    n_cons_total = num_all_constraints(graph)
    n_linkcons_total = num_all_linkconstraints(graph)

    n_all_cons_total = n_cons_total + n_linkcons_total #n_link_edges_total

    if n_all_cons_total >= 5
        yticks = Int64.(round.(collect(range(0,stop = n_all_cons_total,length = 5))))
    else
        yticks = Int64.(round.(collect(range(0,stop = n_all_cons_total,length = n_all_cons_total + 1))))
    end

    #Setup plot dimensions
    plt = Plots.plot(;xlims = [0,n_vars_total],ylims = [0,n_all_cons_total],legend = false,framestyle = :box,xlabel = "Node Variables",ylabel = "Constraints",size = (800,800),
    guidefontsize = 24,tickfontsize = 18,grid = false,yticks = yticks)

    #plot top level nodes, then start going down subgraphs
    n_link_constraints = num_linkconstraints(graph)  #local links
    col = 0
    node_indices = Dict()
    node_col_ranges = Dict()
    for (i,node) in enumerate(all_nodes(graph))
        node_indices[node] = i
        node_col_ranges[node] = [col,col + num_variables(node)]
        col += num_variables(node)
    end

    row = n_all_cons_total  - n_link_constraints #- height_initial
    #draw node blocks for this graph
    for (i,node) in enumerate(getnodes(graph))
        height = num_constraints(node)
        row -= height
        #row_start,row_end = node_row_ranges[node]
        row_start = row
        col_start,col_end = node_col_ranges[node]
        width = col_end - col_start

        row_end = row - height
        rec = rectangle(width,height,col_start,row_start)

        if !(node_colors)
            Plots.plot!(plt,rec,opacity = 1.0,color = :grey)
        else
            Plots.plot!(plt,rec,opacity = 1.0,color = node_cols[i])
        end
        if node_labels
            Plots.annotate!(plt,(col_start + width + col_start)/2,(row + height + row)/2,Plots.text(node.label,labelsize))
        end
    end

    #plot link constraints for highest level using rectangles
    row = n_all_cons_total
    #recs = []

    link_rows = []
    link_cols = []
    for link in getlinkconstraints(graph)
        #row -= 1

        linkcon = constraint_object(link)
        vars = keys(linkcon.func.terms)
        for var in vars
            node = getnode(var)

            col_start,col_end = node_col_ranges[node]
            col_start = col_start + var.index.value - 1 + 0.5



            #these are just points.
            #rec = rectangle(1,1,col_start,row)
            push!(link_rows,row - 0.5)
            push!(link_cols,col_start)
            # Plots.plot!(plt,rec,opacity = 1.0,color = :blue);
        end
        row -= 1
    end
    Plots.scatter!(plt,link_cols,link_rows,markersize = markersize,markercolor = :blue,markershape = :rect);

    if length(graph.optinodes) > 0
        row -= 1
    end

    _plot_subgraphs!(graph,plt,node_col_ranges,row,node_labels = node_labels,labelsize = labelsize,colors = colors,markersize = markersize)
    return plt
end

function _plot_subgraphs!(graph::OptiGraph,plt,node_col_ranges,row_start_graph;node_labels = false,labelsize = 24,colors = nothing,markersize = 1)
    if colors == nothing
        colors = [Colors.parse(Colorant,"grey") for _= 1:length(graph.subgraphs)]
    end


    row_start_graph = row_start_graph
    for (i,subgraph) in enumerate(getsubgraphs(graph))


        link_rows = []
        link_cols = []
        row = row_start_graph#

        for link in getlinkconstraints(subgraph)
            #row -= 1
            #nodes = getnodes(link)
            linkcon = constraint_object(link)
            vars = keys(linkcon.func.terms)
            for var in vars
                node = getnode(var)
                col_start,col_end = node_col_ranges[node]
                col_start = col_start + var.index.value - 1 + 0.5
                # rec = rectangle(1,1,col_start,row)
                # Plots.plot!(plt,rec,opacity = 1.0,color = :blue)
                push!(link_rows,row - 0.5)
                push!(link_cols,col_start)
            end
            row -= 1
        end
        Plots.scatter!(plt,link_cols,link_rows,markersize = markersize,markercolor = :blue,markershape = :rect);

        if !(isempty(subgraph.optinodes))
            subgraph_col_start = node_col_ranges[subgraph.optinodes[1]][1]
        else
            subgraph_col_start = 0
        end

        #draw node blocks for this graph
        for node in getnodes(subgraph)
            height = num_constraints(node)
            row -= height
            row_start = row
            col_start,col_end = node_col_ranges[node]
            width = col_end - col_start

            rec = rectangle(width,height,col_start,row_start)
            Plots.plot!(plt,rec,opacity = 1.0,color = colors[i])
            if node_labels
                Plots.annotate!(plt,(col_start + width + col_start)/2,(row + height + row)/2,Plots.text(node.label,labelsize))
            end

        end

        _plot_subgraphs!(subgraph,plt,node_col_ranges,row,node_labels = node_labels,labelsize = labelsize)

        num_cons = num_all_constraints(subgraph) + num_all_linkconstraints(subgraph)
        num_vars = num_all_variables(subgraph)
        row_start_graph -= num_cons
        subgraph_row_start = row_start_graph

        rec = rectangle(num_vars,num_cons,subgraph_col_start,subgraph_row_start)
        Plots.plot!(plt,rec,opacity = 0.1,color = colors[i])

    end
end

#Overlap spy
function Plots.spy(graph::OptiGraph,subgraphs::Vector{OptiGraph};node_labels = false,labelsize = 24,subgraph_colors = true)

    n_graphs = length(subgraphs)
    if subgraph_colors
        cols = Colors.distinguishable_colors(n_graphs + 1)
        if cols[1] == Colors.parse(Colorant,"black")
            cols[1] = Colors.parse(Colorant,"grey")
        end
        colors = cols[2:end]
    else
        colors = [Colors.parse(Colorant,"grey") for _= 1:n_graphs]
    end

    #Plot limits
    n_vars_total = sum(num_variables.(subgraphs)) #+ sum(num_variables.(getnodes(graph))) #master
    n_cons_total = sum(num_all_constraints.(subgraphs)) #+ sum(num_constraints.(getnodes(graph))) #+ num_linkconstraints(graph)
    n_linkcons_total = sum(num_all_linkconstraints.(subgraphs)) #+ num_all_linkconstraints(graph)

    n_all_cons_total = n_cons_total + n_linkcons_total

    if n_all_cons_total >= 5
        yticks = Int64.(round.(collect(range(0,stop = n_all_cons_total,length = 5))))
    else
        yticks = Int64.(round.(collect(range(0,stop = n_all_cons_total,length = n_all_cons_total + 1))))
    end

    #Setup plot dimensions
    plt = Plots.plot(;xlims = [0,n_vars_total],ylims = [0,n_all_cons_total],legend = false,framestyle = :box,xlabel = "Node Variables",ylabel = "Constraints",size = (800,800),
    guidefontsize = 24,tickfontsize = 18,grid = false,yticks = yticks)

    row_start_graph = n_all_cons_total - 1
    col_start_graph = 1
    for i = 1:length(subgraphs)
        subgraph = subgraphs[i]
        #column data for subgraph
        node_indices = Dict()
        node_col_ranges = Dict()

        col = col_start_graph
        for (i,node) in enumerate(all_nodes(subgraph))
            node_indices[node] = i
            node_col_ranges[node] = [col,col + num_variables(node)]
            col += num_variables(node)
        end

        #Now just plot columns of overlap nodes
        nodes = all_nodes(subgraph)
        overlap_nodes = Dict()
        for j = 1:length(subgraphs)
            if j != i
                other_subgraph = subgraphs[j]
                other_nodes = all_nodes(other_subgraph)
                overlap = intersect(nodes,other_nodes)
                overlap_nodes[j] = overlap
            end
        end
                #plot local column overlap
        link_rows = []
        link_cols = []
        row = row_start_graph
        for link in getlinkconstraints(subgraph)
            row -= 1
            linkcon = constraint_object(link)
            vars = keys(linkcon.func.terms)
            for var in vars
                node = getnode(var)
                col_start,col_end = node_col_ranges[node]
                col_start = col_start + var.index.value - 1
                push!(link_rows,row)
                push!(link_cols,col_start)
            end
        end
        Plots.scatter!(plt,link_cols,link_rows,markersize = 1,markercolor = :blue,markershape = :rect);

        #draw node blocks for this graph
        for node in getnodes(subgraph)
            height = num_constraints(node)
            row -= height
            row_start = row
            col_start,col_end = node_col_ranges[node]
            width = col_end - col_start

            rec = rectangle(width,height,col_start,row_start)
            Plots.plot!(plt,rec,opacity = 1.0,color = colors[i])
            if node_labels
                Plots.annotate!(plt,(col_start + width + col_start)/2,(row + height + row)/2,Plots.text(node.label,labelsize))
            end
        end

        num_cons = num_all_constraints(subgraph) + num_all_linkconstraints(subgraph)
        num_vars = num_all_variables(subgraph)

        subgraph_plt_start = row
        rec = rectangle(num_vars,num_cons,col_start_graph,subgraph_plt_start)
        Plots.plot!(plt,rec,opacity = 0.1,color = colors[i])

        #overlap rectanges
        for (j,overlap) in overlap_nodes
            for node in overlap
                col_start,col_end = node_col_ranges[node]
                rec = rectangle(num_variables(node),num_cons,col_start,subgraph_plt_start)
                Plots.plot!(plt,rec,opacity = 0.1,color = colors[j])
            end
        end

        col_start_graph = col
        row_start_graph = row
    end

    return plt
end
