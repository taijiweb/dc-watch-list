{react} = flow = require('lazy-flow')
{isArray} = require('dc-util')
extend = require('extend')

module.exports = flow

slice = Array.prototype.slice

flow.watchList = watchList = (listItems, listComponent) ->

  watchingListComponents = listItems.watchingListComponents  || listItems.watchingListComponents = {}
  watchingListComponents[listComponent.dcid] = listComponent

  if listItems.eachWatching
    return

  listItems.eachWatching = true

  listItems._shift = listItems.shift
  listItems._pop = listItems.pop
  listItems._push = listItems.push
  listItems._reverse = listItems.reverse
  listItems._sort = listItems.sort
  listItems._splice = listItems.splice
  listItems._unshift  = listItems.unshift

  listItems.shift = ListWatchMixin.shift
  listItems.pop = ListWatchMixin.pop
  listItems.push = ListWatchMixin.push
  listItems.reverse = ListWatchMixin.reverse
  listItems.sort = ListWatchMixin.sort
  listItems.splice = ListWatchMixin.splice
  listItems.unshift  = ListWatchMixin.unshift
  listItems.setItem  = ListWatchMixin.setItem
  listItems.setLength  = ListWatchMixin.setLength
  listItems.updateComponents  = ListWatchMixin.updateComponents
  listItems.updateComponent  = ListWatchMixin.updateComponent
  listItems.getListChildren  = ListWatchMixin.getListChildren
  listItems.replaceAll = ListWatchMixin.replaceAll

ListWatchMixin = {}

ListWatchMixin.getListChildren = (listComponent, start, stop) ->
  children = []
  i = start
  while i < stop
    itemComponent = listComponent.getItemComponent(this[i], i)
    # ensure it can be invalidate again while setItem
    itemComponent.valid = true
    children.push(itemComponent)
    i++
  children

ListWatchMixin.updateComponent = (listComponent, start, stop) ->
  children = this.getListChildren(listComponent, start, stop)
  listComponent.setChildren(start, children)
  this

ListWatchMixin.updateComponents = (start, stop) ->
  watchingListComponents = this.watchingListComponents
  for _, listComponent of watchingListComponents
    this.updateComponent(listComponent, start, stop)
  this

ListWatchMixin.setItem = (start, values...) ->
  start = start >>> 0
  if start<0
    start = 0

  for value, i in values
    this[start+i] = values[i]

  this.updateComponents(start, start+values.length)
  this

ListWatchMixin.pop = ->
  if !this.length
    return
  else
    watchingListComponents = this.watchingListComponents
    result = this._pop()
    for _, listComponent of watchingListComponents
      listComponent.popChild()
    result

ListWatchMixin.push = (args...)->
  watchingListComponents = this.watchingListComponents
  length = this.length
  result = this._push.apply(this, arguments)
  for _, listComponent of watchingListComponents
    child = listComponent.getItemComponent(this[length], length)
    listComponent.pushChild(child)
  result

ListWatchMixin.unshift = (args...) ->
  if !this.length
    this
  else
    watchingListComponents = this.watchingListComponents
    this._shift()
    length = this.length
    for _, listComponent of watchingListComponents
      if !listComponent.updateSuccChild
        listComponent.shiftChild()
      else
        this.updateComponent(listComponent, length)
    this

ListWatchMixin.unshift = (child) ->
  this._unshift(child)
  watchingListComponents = this.watchingListComponents
  for _, listComponent of watchingListComponents
    if !listComponent.updateSuccChild
      child = listComponent.getItemComponent(this[0], 0)
      listComponent.unshiftChild(child)
    else
      this.updateComponent(listComponent, this.length)

ListWatchMixin.reverse = ->
  listLength = this.length
  if listLength <= 1
    this
  else
    this._reverse()
    this.updateComponents(0, listLength)

ListWatchMixin.sort = ->
  listLength = this.length
  if listLength <= 1
    this
  else
    this._sort()
    this.updateComponents(0, listLength)

ListWatchMixin.splice = (start, deleteCount) ->
  inserted = slice.call(arguments, 2)
  insertedLength = inserted.length

  if deleteCount == 0 && insertedLength == 0
    this
  else
    oldListLength = this.length
    start  = start >>> 0
    if start < 0
      start = 0
    else if start > oldListLength
      start = oldListLength
    result = this._splice.apply(this, [start, deleteCount].concat(inserted))
    newLength = this.length
    if newLength == oldListLength
      this.updateComponents(start, start+insertedLength)
    else
      watchingListComponents = this.watchingListComponents
      for _, listComponent of watchingListComponents
        if !listComponent.updateSuccChild
          if insertedLength > deleteCount
            i = start
            j = 0
            while j < deleteCount
              child = listComponent.getItemComponent(this[i], i)
              listComponent.replaceChild(i, child)
              i++
              j++
            while j < insertedLength
              child = listComponent.getItemComponent(this[i], i)
              listComponent.insertChild(i, child)
              i++
              j++
          else
            i = start
            j = 0
            while j < insertedLength
              child = listComponent.getItemComponent(this[i], i)
              listComponent.replaceChild(i, child)
              i++
              j++
            while j < deleteCount
              listComponent.removeChild(i)
              j++
        else
          this.updateComponent(listComponent, start, newLength)
    this

ListWatchMixin.setLength = (length) ->
  oldListLength = this.length
  if length == oldListLength
    this
  else if length <= oldListLength
    watchingListComponents = this.watchingListComponents
    this.length = length
    for _, listComponent of watchingListComponents
      listComponent.setLength(length)
    this
  else
    this.updateComponents(oldListLength, length)
    this

ListWatchMixin.replaceAll = (newItems) ->
  this.setItem(0, newItems...)
  this.setLength(newItems.length)
  this

flow.watchObject = watchObject = (objectItems, listComponent, itemFn) ->

  watchingListComponents = objectItems.watchingListComponents || objectItems.watchingListComponents = {}
  watchingListComponents[listComponent.dcid] = listComponent

  if objectItems.eachWatching
    return

  objectItems.eachWatching = true

  extend(objectItems, ObjectWatchMixin)

ObjectWatchMixin = {}

ObjectWatchMixin.deleteItem = (keys...) ->
  watchingListComponents = this.watchingListComponents
  if !watchingListComponents.length
    return this
  for key in keys
    if this.hasOwnProperty(key)
      if key[..2] == '$dc'  # $dcSetItem, $dcDeleteItem, $dcExtendItems, watchingListComponents
        throw new Error('do not remove the key: ' + key + ', which is used by "each component" of dc')
      delete this[key]
      for _, listComponent of watchingListComponents
        keyChildMap = listComponent.keyChildMap
        index = keyChildMap[key]
        children = listComponent.children
        length = children.length
        break
      for _, listComponent of watchingListComponents
        if !listComponent.updateSuccChild
          listComponent.removeChild(index)
        else
          i = index + 1
          children = listComponent.children
          while i < length
            oldChild = children[i]
            newChild = listComponent.getItemComponent(oldChild.$watchingKey, i, this, listComponent)
            listComponent.replaceChild(oldChild, newChild)
            i++
          listComponent.removeChild(index)
        delete keyChildMap[key]
  this

ObjectWatchMixin.setItem = (key, value) ->
  if isEachObjectSystemKey(key)  # $dcSetItem, $dcDeleteItem, $dcExtendItems, watchingListComponents
    throw new Error('do not use the key: ' + key + ', which is used by "each component" of dc')
  watchingListComponents = this.watchingListComponents
  if this.hasOwnProperty(key)
    this[key] = value
    for _, listComponent of watchingListComponents
      oldChildIndex = listComponent.keyChildMap[key]
      newChild = listComponent.getItemComponent(key, oldChildIndex, this, listComponent)
      listComponent.replaceChild(oldChild, newChild)
  else
    length = listComponent.children.length
    for _, listComponent of watchingListComponents
      newChild = listComponent.getItemComponent(key, length, this, listComponent)
      listComponent.pushChild(newChild)
  this

ObjectWatchMixin.extendItems = (obj) ->
  for key, value of obj
    this.setItem(key, value)
  this

ObjectWatchMixin.replaceAll = (obj) ->
  keys = Object.keys(this)
  for key in keys
    if !obj.hasOwnProperty(key)
      this.deleteItem(key)
  this.extendItems(obj)
  this

flow.isEachObjectSystemKey = isEachObjectSystemKey = (key) ->
  /setItem|deleteItem|extendItems|watchingListComponents|eachWatching/.test(key)
  
flow.watchItems = (items, listComponent) ->
  if !items
    throw new Error('items to be watched should be an array or object.')
  if isArray(items)
    watchList(items, listComponent)
  else
    watchObject(items, listComponent)

  listComponent


   