--Generate the values
function generateValues()
	local force = game.forces["player"]
	
	--Get item names
	for name, prototype in pairs(game.item_prototypes) do
		global.item_values[name] = global.item_values[name] or 0
	end
	
	--Get fluid names
	for name, prototype in pairs(game.fluid_prototypes) do
		global.item_values[name] = global.item_values[name] or 0
	end
	
	--TODO - not sure if I want to try to do something with tech values or not
	--Get tech values 
	--[[
	for name, tech in pairs(force.technologies) do
		generateTechValue(tech)
	end
	]]
	
	--Get a table of products of recipes
	local product_table = {} --[itemName] = {} of recipe
	for recipeName, recipe in pairs(force.recipes) do
		for _, product in pairs(recipe.products) do
			if not product_table[product.name] then product_table[product.name] = {} end
			table.insert(product_table[product.name], recipe)
		end
	end
	
	--Generate prices untill there aren't any more that can be generated
	--This will make sure that the lowest value is used when possible
	local newValues = true
	while newValues do
		temp_values = {} --[itemName] = value
		newValues = false
		
		--Generate a value if possible for each recipe
		for itemName, recipes in pairs(product_table) do
			for _, recipe in pairs(recipes) do
				if generateValueFromRecipe(itemName, recipe) then
					local testFunc = function(arg) return arg.name == recipe.name end
					
					product_table[itemName] = removeFromTable(testFunc, recipes)
				end
			end
		end
		
		--Transfer the temporary values to the main global table
		for itemName, value in pairs(temp_values) do
			if global.item_values[itemName] then
				if global.item_values[itemName] ~= 0 then
					global.item_values[itemName] = math.min(global.item_values[itemName], value)
				else
					global.item_values[itemName] = value
				end
				newValues = true
			end
		end
		temp_values = nil
	end
	
	--Remove the unneeded items
	for name, prototype in pairs(game.item_prototypes) do
		if prototype.has_flag("hidden") then
			local func = function(arg) return arg == name end
			global.item_values = removeFromTableWithKey(func, global.item_values)
		end
	end
	
	--Remove the fluids
	for name, prototype in pairs(game.fluid_prototypes) do
		local func = function(arg) return arg == name end
		
		global.item_values = removeFromTableWithKey(func, global.item_values)
	end
	
	--Log the value list
	printValueList()
end
--[[
function generateTechValue(tech)
	local value = 0
	for name, prerequisite in pairs(tech.prerequisites) do
		if global.tech_values[name] then
			value = global.tech_values[name] + 1
		else
			value = generateTechValue(prerequisite) + 1
		end
	end
	Debug.log(tech.name)
	for _, effect in pairs(tech.effects) do
		if effect.type == "unlock-recipe" then
			Debug.log(effect.recipe)
			global.recipe_tech_values[effect.recipe] = value
		end
	end
	
	global.tech_values[tech.name] = value
	return value
end
]]

--Return true if generated new value
--Put the value in temp_values table
--This recipe is being used to generate a value for itemName
-- @param itemName string
-- @param recipe obj
-- @return true or false if a value was generated
-- Side Effect: put the generated value into temp_values
function generateValueFromRecipe(itemName, recipe)
	local price = 0
	for _, ingredient in pairs(recipe.ingredients) do
		local ingredientName = ingredient.name
		
		if global.item_values[ingredientName] == 0 then return false end
		
		--Calculate the base value
		local baseValue = global.item_values[ingredientName] * ingredient.amount * ingredient_modifier
		
		--Calculate the tech value
		--local techValue = global.recipe_tech_values[ingredientName] * tech_level_modifier
		
		price = price + baseValue-- + techValue
	end
	
	--Calculate the energy value
	local energyValue = recipe.energy * energy_modifier
	
	--Finalize the price
	price = price * energyValue
	price = price * overall_modifier
	
	--Assign the value or split it based on different products
	local products = recipe.products
	if #products == 1 then
		local product = products[1]
		if product.name == itemName then
			temp_values[itemName] = math.ceil(price/getProductAmount(product))
		end
	else
		local totalAmount = 0
		for _, product in ipairs(products) do
			totalAmount = totalAmount + getProductAmount(product)
		end
		
		for _, product in ipairs(products) do
			if product.name == itemName then
				temp_values[itemName] = math.ceil(price/(getProductAmount(product)/totalAmount))
			end
		end
	end
	return true
end

--Get the product's amount based on factors within the product
-- @param product obj
-- @return product amount
function getProductAmount(product)
	local probability = product.probability or 1
			
	if product.amount then
		return product.amount
	else
		return (product.amount_max - product.amount_min) * probability
	end
end

--Logs the value list 
function printValueList()
	Debug.log_no_tick("Item"..getSpacing(4).."| Price")
	for name, price in pairs(global.item_values) do
		Debug.log_no_tick(name..getSpacing(#name)..price)
	end
end

--Spacing for value list log
function getSpacing(length)
	local s = ""
	for i=1, 50-length do
		s = s.." "
	end
	return s
end