var TextCode = {

    show_raw        : function( id ) {
        $( id + '-raw' ).fadeIn();
        $( id + '-html' ).fadeOut();
    },

    show_html       : function( id ) {
        $( id + '-html' ).fadeIn();
        $( id + '-raw' ).fadeOut();
    },

    show_toolbar    : function( id ) {
        $( id + '-toolbar' ).show();
    },

    hide_toolbar    : function( id ) {
        $( id + '-toolbar' ).hide();
    }

};

$(document).ready( function() {
    $( '.text-code-show-raw' ).click( function( event ) {
        console.log( $(this).closest( '.text-code' ) );
    } );
    $( '.text-code-show-html' ).click( function( event ) {
        console.log( $(this).closest( '.text-code' ) );
    } );
/*
    $( '.text-code-tools a.button' ).click( function( event ) {
        console.log( 'event.target', event.target );
        var id = $( this ).parent().parent().attr( 'id' );
        var which = id + '-' + $( this ).html();
        $( '#' + id ).children( '.text-code-view' ).each( function( i, el ) {
            console.log( el.id );
            if ( el.id === which ) {
                $( el ).show();
            } else {
                $( el ).hide();
            }
        } );

        event.preventDefault();
    } );
*/
    $( 'span.text-code-buttons' ).css( 'display', '' );
} );
