class sStory
  constructor: (@story_list) ->   
    typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
     
    if @story_list is undefined
      throw "No story_list defined"
      
    if !typeIsArray(@story_list)
      throw "The story_list is not an array"
    
  render: ->
    $content = $('#content')
    $content.html("")
    
    templates = {}
    $(".section-template").each(->
        templateSource = $(this).html()
        templates[$(this).attr('id')] = Handlebars.compile(templateSource)
    )
    
    _.each(@story_list, (section, i) ->
        #console.log "section =>", section
        # Append the contents of each section to the page
        sectionHtml = templates["section-template-"+section.type](section)
        sectionContent = $("<section id='"+i+"' class='"+section.type+"'></section>").html(sectionHtml)
        $content.append(sectionContent)
    )
    # $content.append(JSON.stringify(@story_list))
    
    
    
    @handleWindowResize()
    that = this
    $(window).on('resize', -> that.handleWindowResize() )
    
    @renderMaps()
    @renderTimelines()
    @makeNavSectionList()
    
    return @story_list
    
  makeNavSectionList: ->
    $navlist = $("#nav-section-list")
    $navlist.html("")
    
    _.each(@story_list, (section, i) ->
      #console.log section  
      $navlist.append(i + 1)      
    )
    
  #story_list: ->
    # Return the master story list object, the heart of everything
    #@story_list
    
  verticalCenterElement: (el, parEl)->
    elHeight = el.innerHeight() / 2
    pageHeight = parEl.innerHeight() / 2

    $(el).css({
        paddingTop: (pageHeight - elHeight)
    })
    
  verticalCenterPhotoTitles: ->
    that = this
    $(".photoBigText h2").each(->
      that.verticalCenterElement( $(this), $(this).parent() )
    )
    
    $(".photoCaption h2").each(->
      that.verticalCenterElement( $(this), $(this).parent() )
    )
    
  handleWindowResize: ->
    @verticalCenterPhotoTitles()
    
    windowHeight = $(window).height()
    $(".photoBigText .photo-background").css({
        minHeight: windowHeight
    })
    $(".photoCaption .photo-background").css({
        minHeight: windowHeight
    })
    
  renderTimelines: ->
    that = this
    $(".verite-timeline").each(->
      timelineId = _.uniqueId("timeline_")
      $(this).attr("id", timelineId)
      spreadsheetAddr = $(this).attr("data-spreadsheet-address")
      
      createStoryJS({
           type:       'timeline'
           width:      '100%'
           height:     '600'
           source:     spreadsheetAddr
           embed_id:   timelineId
       });
      
    )
    
  renderMaps: ->
    that = this
    $(".single-location-map").each(->
      mapId = _.uniqueId("map_")
      $(this).attr("id", mapId)
      
      address = $(this).attr("data-address")
      caption = $(this).attr("data-caption")
      
      latLon = []
      
      geoCode = that.geocodeLocationRequest(address)
      
      geoCode.done( (result) ->
        #console.log("geoCode result", result)
        result = result[0]
        latLon = [result.lat, result.lon]
        
        map = L.map(mapId, {
            scrollWheelZoom: false          
        }).setView(latLon, 14)
              
        layer = new L.StamenTileLayer("toner-lite");
        map.addLayer(layer);
        
        circle = L.circle(latLon, 120, {
            color: 'red'
            fillColor: 'red'
            fillOpacity: 0.5
            closeOnClick: false
        })
        .bindPopup(caption, {
            maxWidth: 600
            maxHeight: 600
            closeButton: false  
        })
        .addTo(map)
        .openPopup();
        
      )      
    )
    
  geocodeLocationRequest: (location) ->
  	#console.log("Location", location)
  	baseUrl = "http://open.mapquestapi.com/nominatim/v1/search.php?format=json"
  	addr = "&q="+location

  	url = encodeURI(baseUrl + addr + "&addressdetails=1&limit=1")

  	$.ajax({
  		url: url
  		type: "GET"
  		dataType: "json"
  		cache: true
  	})
  
    
class sStoryEditor
  constructor: (@story) -> 
    
    $("#story-editor").show()
       
    @sectionTypes =
      photo:
        photoBigText:
          inputs: ['title', 'photoUrl']
          mustHave: ['photoUrl']
        photoCaption:
          inputs: ['title', 'photoUrl', 'caption']
          mustHave: ['photoUrl', 'caption']
      video:
        videoYoutube:
          inputs: ['embedCode']
          mustHave: ['embedCode']
        videoVimeo:
          inputs: ['embedCode']
          mustHave: ['embedCode']
      sound:
        soundSoundcloud:
          inputs: ['embedCode']
          mustHave: ['embedCode']
      location:
        locationSinglePlace:
          inputs: ['address', 'caption', 'photoUrl']
          mustHave: ['address', 'caption']
      timeline:
        timelineVerite:
          inputs: ['title', 'googleSpreadsheet']
          mustHave: ['googleSpreadsheet']
    
    @giveSectionsID()
    @renderSectionList()
    @renderSectionTypeSelector()
  
  giveSectionsID: () ->
    newStory = []

    _.each(@story.story_list, (section) ->
        if section.id is undefined
          section.id = _.uniqueId("s")
        newStory.push(section)
    )
    @story.story_list = newStory
    
  renderSectionEditor: ->
    # Depending on what type of section the user wants to add
    # we show a different set of inputs which are grabbed
    # from their Handlebars templates
    
    templates = {}
    $(".editor-template").each(->
        templateSource = $(this).html()
        templates[$(this).attr('id')] = Handlebars.compile(templateSource)
    )
    
    newSectionType = $("#new-section-type").val()
    newSectionSubType = $("#sub-section-type").val()    
    
    $editor = $("#editor-inputs")

    $editor.html("")
    that = this
    _.each(@sectionTypes[newSectionType][newSectionSubType].inputs, (input) ->
        sectionData = that.sectionTypes[newSectionType][newSectionSubType]

        mustHave = $.inArray(input, sectionData.mustHave) > -1
        
        $template = $(templates['editor-template-'+input]())
        
        if mustHave
          $template.addClass("must-have")
        
        $editor.append($template)
    )
    
    $("#story-editor #save").on("click", -> that.exportStoryList())
    
    document.getElementById('story_file').addEventListener('change',( -> that.importStoryList(event, that) ), false)
  
    $("#add-section").on("click", ->
        that.addSection()
        $("#editor-inputs input").val(" ")
    )
    
  renderSectionList: ->
    # Render a re-arrangeable list of each section for the editor
    $content = $('#section-list')
    
    $content.html("")
    
    that = this
    
    #console.log("@story", @story)
    _.each(@story.story_list, (section, i) ->
        # Append the contents of each section to the page        
        sectionIcon = ""
        sectionMainType = ""
        #console.log section.type
        
        switch section.type
          when "photoBigText"
            sectionMainType = "photo"
          when "photoCaption"
            sectionMainType = "photo"            
          
          when "videoYoutube"
            sectionMainType = "video"
          when "videoVimeo"
            sectionMainType = "video"
            
          when "soundSoundcloud"
            sectionMainType = "sound"
          
          when "locationSinglePlace"
            sectionMainType = "location"
            
          when "timelineVerite"
            sectionMainType = "timeline"
          
        switch sectionMainType
          when "photo"
            sectionIcon = "<i class=\"icon-camera\"></i>"
          when "video"
            sectionIcon = "<i class=\"icon-video\"></i>"
          when "sound"
            sectionIcon = "<i class=\"icon-volume-up\"></i>"
          when "location"
            sectionIcon = "<i class=\"icon-location-circled\"></i>"
          when "timeline"
            sectionIcon = "<i class=\"icon-calendar\"></i>"
        
        deleteIcon = "<i class=\"icon-cancel-squared delete-section\"></i>"
        sectionContent = deleteIcon + sectionIcon + " "
        
        $listItem = $("<li></li>")
          .attr("id", i)
          .attr("data-id", section.id)
          .html(sectionContent)
        
        if section.title isnt undefined
          $listItem.attr("title", section.title)
        
        $content.append($listItem)
        
        $("i.delete-section").on("click", ->
            that.deleteSection($(this).parent().attr('data-id'))
        )
    )
    
    # @TODO Figure out why there are multiple sorting events happening
    # I think we are adding a new binding every time we refresh the list
    # it needs to be destroyed before we re-make it, or check if it's made
    # and only make it if it isn't
    
    $content.sortable("destroy")
    $sortable = $content.sortable()
    
    
    that = this
    
    $sortable.bind('sortupdate', ->        
        sortedList = []
        $(this).children().each(() ->          

            sortedList.push($(this).attr("data-id"))
        )

        that.reorderStoryList(sortedList)
        sortableSet = true
    );
    
  reorderStoryList: (sortedList) ->
    # Given an order-specific array of IDs like ["s1", "s2", "s3"]
    # re-arrange the story_list objects
    oldList = @story.story_list
    
    newStoryList = []
    _.each(sortedList, (listItemID) ->
      section = _.find(oldList, (section) ->
          return section.id is listItemID
      )
      
      newStoryList.push(section)      
    )
    @story.story_list = newStoryList
    
    @updatePage()
    
  updatePage: ->
    # Update the pagee    
    @renderSectionList()
    @story.render()
    @story.handleWindowResize()
    
    
  renderSectionSubTypeSelector: (section) ->
    # Each section type has a subtype, for example
    # photo has the subtypes 'photoBigText' and 'photoCaption'
    # so we render a selector for each of these subtypes
 
    if section is undefined
      section = "photo"
      
    subsections = @sectionTypes[section]
    $select = $("#sub-section-type")
    
    $select.html("")
    
    _.each(_.keys(subsections), (sectionType) -> 
      $option = $('<option value="'+sectionType+'">'+sectionType+'</option>')
      $select.append($option)
    )
    
    that = this
    $select.on("change", ->
      that.renderSectionEditor()
    )
    
  
  renderSectionTypeSelector: ->
    # Each section type has a type, like 'photo', 'video', 'audio'
    # we want to render a selector for each of these types
    
    $select = $("#new-section-type")
    $select.html("")

    _.each(_.keys(@sectionTypes), (sectionType) ->
      $option = $('<option value="'+sectionType+'">'+sectionType+'</option>')
      $select.append($option)
    )
  
    that = this
    $select.on("change", ->
      that.renderSectionSubTypeSelector($(this).val())
      that.renderSectionEditor()
    )

    @renderSectionSubTypeSelector()
    @renderSectionEditor()
    
  deleteSection: (delSection) ->
    # Given a section's number in the story_list array
    # Delete it!
    console.log("Delete "+delSection)
    
    newlist = _.reject(@story.story_list, (section, k) ->
        console.log("k>", k, "delSection>", delSection)
        if section.id is delSection
          return true
        else
          false
    )
    
    @story.story_list = newlist
    console.log('@story', @story)

    @updatePage()
    
  addSection: (section) ->
    # Add a new section to @story.list()
    
    sectionCount = d3.max(_.keys(@story.story_list)); # Figure how many sections there are
    #console.log("count:", sectionCount)
    
    if sectionCount is undefined
      sectionCount = 0
    
    # Create the new section     
    newSectionNum = (+sectionCount)+1
    
    newSection = {}
    
    $("#editor-inputs input").each((el) ->
        # For every input that isn't blank, add it to the section
        if $(this).val() isnt ""          
          newSection[$(this).attr('id').split("-")[2]] = $(this).val()
    )
    
    newSection.type = $("#sub-section-type").val() 
    
    @story.story_list[newSectionNum] = newSection
    console.log("=>", @story)
    
    # Give the new section an ID 
    @giveSectionsID()
    
    @updatePage()
    
  exportStoryList: ->
    # Save the story list as a JSON file
    blob = new Blob([JSON.stringify(@story.story_list)], {type: "application/json;charset=utf-8"});
    saveAs(blob, "sstory.json");
    
  importStoryList: (evt, that) ->

    files = evt.target.files
    fileJson = []
    
    reader = new FileReader();
    
    reader.onload = ((thefile) ->
      (e) ->
        fileJson = JSON.parse(e.target.result)
        
        that.story.story_list = fileJson
        that.story.render()
        that.giveSectionsID()
        that.renderSectionList()
        
        $("#story-editor #story_file").hide()
        
    )(files[0])
        
    reader.readAsBinaryString(files[0])    
    
  makeTitlesEditable: ->
    console.log "make all the titles contentEditable and add some bindings"
    
  updateSectionTitle: (sectionID, newtitle) ->
    console.log sectionID, newtitle

