jQuery(function($) {
  $('ol.queues li .sort')
    .bind('dragstart', function(event) {
      return $(event.target).parents('li:first').clone().css('position', 'absolute').appendTo(document.body);
    })
    .bind('drag', function(event) {
      $(event.dragProxy).css({
        top: event.offsetY,
        left: event.offsetX
      });
    })
    .bind('dragend', function(event) {
      $(event.dragProxy).remove();
    });
    
  $('ol.queues > li')
    .bind('dropstart', function(event) {
      $(event.dropTarget).addClass('droptarget');
    })
    .bind('drop', function(event) {
      // $(event.dropTarget).before($(event.dragTarget).parents('li:first'));
    })
    .bind('dropend', function(event) {
      $(event.dropTarget).removeClass('droptarget');
    });
});