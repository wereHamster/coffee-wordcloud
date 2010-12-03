
# This class is a really simple wrapper around a Raphaël container. It draws
# a wordcloud (list of words), with the font size varying according to the
# importance (or some other metric) of those words.

class WordCloud

  # Container is the html element into which we put the container. The width/height
  # default to the width/height of the container.
  constructor: (container, width = $(container).getWidth(), height = $(container).getHeight()) ->
    # The Raphaël container used to draw the words.
    @container = Raphael container, width, height

    # Bounding boxes of elements already in the container. This is used to check
    # whether the word we're trying to add is colliding with anything already
    # in the container.
    @elements = []

  # Draw the given words into the container.
  draw: (words) ->
    words = words.sort (a, b) -> b.value - a.value
    [ @maxValue, @minValue ] = [ words[0].value, words[words.length - 1].value ]

    # For each word, create the text element, place it in the container and
    # push its bounding box into the element list.
    for word in words
      @elements.push @placeInContainer @textElement word.key, word.value

  placeInContainer: (e) ->
    # When we don't find space for the word within this radius we give up.
    maxRadius = Math.sqrt Math.pow(@container.width, 2) + Math.pow(@container.height, 2)

    # The bounding box which is used to find a space in the container, and
    # the starting position which is later used to actually reposition the
    # element. We only update the bounding box in the loop because moving
    # the actual element is way too slow.
    box = e.getBBox()
    { x, y } = box

    # Go along a spiral and put it into the first spot where it doesn't
    # collide with any other words.
    @spiral @choice([-1, 1]), (dx, dy) =>
      return true if Math.min(dx, dy) > maxRadius

      # dx/dy are offset from the original position. Adjust the box accordingly.
      [ box.x, box.y ] = [ x + dx, y + dy ]

      # Try again if there is a collision with an existing word already in
      # the container or the word is not fully within the container.
      if @collidesWithExitingElements(box) or not @isWithinContainer(box)
        return false

      # Yay, we found a space, stop the loop
      return true

    # Actually move the element and return its bounding box.
    e.attr x: e.attr('x') + box.x - x, y: e.attr('y') + box.y - y
    e.getBBox()

  # Create a text element from the given word. The font size is calculated
  # from the value. All other styling (font face, color etc) can be changed
  # through CSS.
  textElement: (word, value) ->
    e = @container.text @container.width / 2, @container.height / 2, word
    e.attr 'font-size': @fontSize(value) + 'px'
    e

  # Calculate the font size.
  fontSize: (value, minsize = 20, maxsize = 60) ->
    minsize + (maxsize - minsize) * Math.pow(((value - @minValue) / (@maxValue - @minValue)), 0.75)

  # Return a random integer between min and max
  randint: (min, max) ->
    Math.floor Math.random() * max + min

  # Return a random element from the given array
  choice: (a) ->
    a[@randint(0, a.length)]

  # This function walks a spiral, invoking the callback at each step. The
  # idea is that the callback tries to fit in the word at the given position
  # and if it was successful it exits the loop. The callback is given the
  # offset from the center of the spiral (dx, dy).
  spiral: (direction, callback) ->
    # Feel free to modify these contstants as you like
    DEFAULT_STEP = 0.05
    STEP_SIZE = @randint(1, 5)
    ECCENTRICITY = 1.5
    RADIUS = 5
    t = 0

    # Loop until the callback returns true
    loop
      t += DEFAULT_STEP * STEP_SIZE * direction
      break if callback(ECCENTRICITY * RADIUS * t * Math.cos(t), RADIUS * t * Math.sin(t))

  # Return a boolean indicating whether the given element collides with any
  # of the elements already in the container.
  collidesWithExitingElements: (e) ->
    # Use a random padding around the element. This makes the wordcloud a little
    # bit different each time you generate it.
    padding = @randint(5, 20)

    for o in @elements
      return true unless e.x + e.width + padding < o.x || e.y + e.height + padding < o.y || e.x > o.x + o.width + padding || e.y > o.y + o.height + padding
    false

  # Return a boolean indicating whether the given element is fully within
  # the container.
  isWithinContainer: (e) ->
    e.x > 0 and e.x + e.width < @container.width and e.y > 0 and e.y + e.height < @container.height


# Load the words file and draw then in the word cloud. This uses prototypejs,
# with the reason being that it's what's shipping with rails. Of course you
# can use jQuery or whatever else there is.
document.observe 'dom:loaded', () ->
  new Ajax.Request 'words.json',
    evalJSON: 'force'
    onSuccess: (request) ->
      wordCloud = new WordCloud 'cloud'
      wordCloud.draw(request.responseJSON)

