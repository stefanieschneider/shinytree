HTMLWidgets.widget({
	name: "tree",
	type: "output",

	factory: function(el, width, height) {
		var tree_id = "#" + el.id + " .tree-container";
		var active_search = {"id": -1, "query": null};

		return {
			renderValue: function(opts) {
				if (!$(tree_id).length) {
					if (typeof opts.plugins === "string") {
						opts.plugins = [opts.plugins];
					}

					$("#" + el.id).html("<div class=\"box\"></div>");

					$("#" + el.id + " .box").html(
						"<div class=\"tree-container\" style=\"width: " + 
						width + "; height: " + height + ";\"></div>"
					);

					if ($.inArray("search", opts.plugins) !== -1) {
						$("#" + el.id + " .box").append(
							"<div class=\"search\"><input type=\"search\" class=\"query form" +
							"-control input-sm\" placeholder=\"Filter\" /><button class=\"cl" +
							"ose\"><i class=\"fa fa-times-circle\"></i></button><button clas" +
							"s=\"check\"></button><code class=\"count\"></code></div>"
						);
					}

					$(tree_id).jstree({
						"core": opts.options, "plugins": opts.plugins,
						"checkbox": set_checkbox(opts)
					});

					set_height(el, tree_id, height);

					$(tree_id).on("open_node.jstree", function (e, data) {
						// if (!opts.options.open_multiple) {
						// 	var nodes_to_keep_open = [data.node.id];
						// 	var node_id = "#" + escape_str(data.node.id);

						// 	$(node_id).parents(".jstree-node").each(function() {
						// 		nodes_to_keep_open.push(this.id);
						// 	});

						// 	$(".jstree-node").each(function() {
						// 		if (nodes_to_keep_open.indexOf(this.id) === -1) {
						// 			if ($(this).find(".jstree-search").length == 0) {
						// 				$(tree_id).jstree().close_node(this.id);
						// 			}
						// 		}
						// 	})
						// }

						set_inputs(el.id + "_opened", data);
						set_height(el, tree_id, height);
					})

					$("#" + el.id + " .query").on("keypress change", function(event) {
						if (event.which == 13) {
							var query = $("#" + el.id + " .query").val();

							if (query.trim().length > 2) {
								if (query != active_search.query) {
									$("#" + el.id + " .check").removeClass("off");
									$(tree_id).jstree(true).close_all();

									if (HTMLWidgets.shinyMode) {
										Shiny.setInputValue(el.id + "_search", query);
										add_loader("#" + el.id + " .box", tree_id);

										active_search.id = 0; 
									} else {
										run_search(el, tree_id); active_search.id = -1;
									}
								} else {
									var search_results = scroll_to(tree_id, active_search.id);

									if (active_search.id == search_results.length - 1) {
										active_search.id = -1; // reset to first node
									}

									active_search.id += 1; // increase to next node
								}

								active_search.query = query;
							}
						}
					});

					$("#" + el.id + " .close").on("click", function() {
						$("#" + el.id + " .query").val("");
						$("#" + el.id + " .count").html("");

						$(tree_id).jstree(true).uncheck_all();
						$(tree_id).jstree(true).clear_search();
						$(tree_id).jstree(true).close_all();

						$("#" + el.id + " .check").removeClass("off");
						Shiny.setInputValue(el.id + "_search", "");
						active_search = {"id": -1, "query": null};
					});

					$("#" + el.id + " .check").on("click", function() {
						$(this).toggleClass("off");

						if($(this).is(".off")) {
							add_loader("#" + el.id + " .box", tree_id);
							var nodes_to_check = [];

							$(tree_id).find(".jstree-search").each(function() {
								nodes_to_check.push(this.id.split("_")[0]);
							});

							while (nodes_to_check.length > 0) {
								var nodes = nodes_to_check.splice(0, 50);
								$(tree_id).jstree(true).select_node(nodes);
							}

							remove_loader("#" + el.id + " .box");
						} else {
							$(tree_id).jstree(true).uncheck_all();
						}
					});

					$(tree_id).on("changed.jstree", function (e, data) {
						if (data && data.selected && data.selected.length) {
							set_inputs(el.id + "_selected", data);
						}

						if (HTMLWidgets.shinyMode) {
							var all_checked = $(tree_id).jstree("get_top_checked");
							Shiny.setInputValue(el.id + "_checked_id", all_checked);
						}
					});
				} else {
					$(tree_id).jstree(true).settings.core = opts.options;
					$(tree_id).jstree(true).settings.plugins = opts.plugins;
					$(tree_id).jstree(true).checkbox = set_checkbox(opts);

					$(tree_id).jstree(true).refresh();

					if (active_search.id > -1) {
						run_search(el, tree_id); // highlight search results

						var n_results = $(tree_id).find(".jstree-search").length
						$("#" + el.id + " .count").html(n_results);
					}
				}

				if (opts.options.scrollbar) {
					$(tree_id).niceScroll({
						horizrailenabled: false, autohidemode: false,
						cursorcolor: "#f0f0f0", enableobserver: true
					});
				} else {
					$(tree_id).getNiceScroll().remove();
				}

				remove_loader("#" + el.id + " .box");
			},

			resize: function(width, height) {

			}
		};
	}
});

function set_height(el, tree_id, height) {
	$(tree_id).css("max-height", height);
	$(tree_id).css("height", "auto");

	$(el).css("height", "100%");
}

function set_inputs(shiny_id, data) {
	if (HTMLWidgets.shinyMode) {
		var matches = data.node.text.match(/>([^<]*?)</gi);

		if (matches) {
			matches = matches[matches.length - 1];
			data.node.text = matches.replace(/<|>/g,"").trim();
		}

		Shiny.setInputValue(shiny_id + "_id", data.node.id);
		Shiny.setInputValue(shiny_id + "_text", data.node.text);
		Shiny.setInputValue(shiny_id + "_state", data.node.state);
		Shiny.setInputValue(shiny_id + "_children", data.node.children);

		data.node.text = data.node.original.text;
	}
}

function escape_str(string) {
	return string.replace(/([;&,.+*~':"!^#$%@\[\]()=>|])/g, "\\$1"); 
}

function set_checkbox(opts) {
	var checkbox = {
		"deselect_all": true, "three_state": false
	};

	if ($.inArray("checkbox", opts.plugins) !== -1) {
		checkbox.deselect_all = false;
		checkbox.cascade = "down+undetermined";
	}

	return checkbox
}

function run_search(el, tree_id) {
	var query = $("#" + el.id + " .query").val();

	if (query.trim().length > 2) {
		$(tree_id).jstree(true).search(query);
	}
}

function scroll_to(tree_id, search_id) {
	var search_results = $(tree_id).find(".jstree-search");
	search_results[search_id].scrollIntoView({behavior: "smooth"});

	return search_results
}

function add_loader(container_id, tree_id) {
	var html = "<div class=\"loader fa-3x\"><i class=\"fas " +
						 "fa-circle-notch fa-spin\"></i></div>";

	$(html).hide().appendTo(container_id).fadeIn();
	var height = $(tree_id).outerHeight(true) + "px";

	$(container_id + " .loader").css("height", height);
	$(container_id + " .loader").css("line-height", height);
}

function remove_loader(container_id) {
	$(container_id + " .loader").fadeOut().remove();
}
