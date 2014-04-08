FBApi = ($,_)->
  class FBApi
    constructor:(@appId)->
      @reset()
      @appId = appId
      @timeout = null
      @TIMEOUT_WAIT = 10000

    reset:->
      @isAuth = false
      @user = null

    _getRoles:(FB)->
      "user_photos"

    _startWaitResponse:(callback)->
      @_stopWaitResponse()
      @timeout = setTimeout (=>
        callback()
        @timeout = null
      ),@TIMEOUT_WAIT

    _stopWaitResponse:->
      clearTimeout @timeout if @timeout?

    _getStatus:(async,FB)->
      @_startWaitResponse =>
        async.reject "not FB connect",FB

      FB.getLoginStatus (r)=>
        @_stopWaitResponse()
        if r.status is "connected"
          @isAuth = true
          async.resolve FB
        else
          @reset()
          async.reject "not auth FB", FB

    checkAuth:->
      async = $.Deferred()
      @getFB().always (data)=>
        if @isAuth
          async.resolve @isAuth
        else
          async.reject data
      async.promise()

    login:->
      async = $.Deferred()
      @getFB().always (authFB,notAuthFB)=>
        if(FB=notAuthFB)
          FB.login ((r)=>
            if r.status is "connected"
              @isAuth = true
              async.resolve FB
            else
              @reset()
              async.reject "not auth FB"
          ),scope:@_getRoles(FB)
        else
          async.resolve FB
      async.promise()

    logout:->
      async = $.Deferred()
      @getFB()
        .done (FB)=>
          FB.logout (r)=>
            if r
              async.resolve FB
              @isAuth = false
            else
              @reset()
              async.reject FB
        .fail (err)->
          async.reject err
      async.promise()

    getFB:->
      async = $.Deferred()
      unless @_$_FB?
        setTimeout (->
          el = document.createElement "script"
          el.type = "text/javascript"
          el.src = "//connect.facebook.net/ru_RU/all.js"
          el.async = true
          document.getElementsByTagName("body")[0].appendChild el
        ), 0
        window.fbAsyncInit = =>
          window.fbAsyncInit = null
          @_$_FB = FB = window.FB
          FB.init
            appId:@appId
            status: true
            cookie: true
            xfbml : true
            oauth : true
          @_getStatus async, FB
      else if @isAuth
        async.resolve @_$_FB
      else
        @_getStatus async, @_$_FB
      async.promise()

    getUser:->
      async = $.Deferred()
      if @user?
        async.resolve @user, FB
      else
        @getFB()
          .done (FB)=>
            FB.api '/me?locale=en_EN', (r)=>
              if !!r.error then async.reject(r.error)
              else
                try
                  rx = /(\d{1,2})\/(\d{1,2})\/(\d{4})/
                  rpl = '$3-$1-$2'
                  birthday = new Date r.birthday.replace(rx,rpl)
                @user =
                  id: r.id
                  first_name: r.first_name
                  last_name: r.last_name
                  username: r.username
                  avatar_url: "https://graph.facebook.com/#{r.id}/picture?width=150&height=150"
                  avatar: "https://graph.facebook.com/#{r.id}/picture?type=square"
                  gender: r.gender
                  birthday: birthday
                  soc_type:"fb"
                async.resolve @user,FB
          .fail (err)->
            async.reject err
      async.promise()

    getAlbums:->
      async = $.Deferred()
      @getFB()
        .done (FB)->
          FB.api {
            method: "fql.multiquery"
            queries:
              query1: "select object_id, owner, created, modified, aid,name,link,photo_count,cover_object_id from album where owner = me()"
              query2: "SELECT pid,src,src_big FROM photo WHERE object_id  IN (SELECT cover_object_id FROM #query1)"
          }, (response)->
            parsed = new Array()
            _.each response[0].fql_result_set, (value,index)->
              thumb_src = response[1].fql_result_set[index].src_big or response[1].fql_result_set[index].src
              parsed.push
                id: value.object_id
                title: value.name
                owner_id: value.owner
                size: parseInt(value.photo_count)
                thumb_id: response[0].fql_result_set[index].cover_object_id
                thumb_src: thumb_src
                created: new Date value.created
                updated: new Date value.modified
                #aid: value.aid
                aid: value.object_id
                album_id: value.object_id
                link: value.link
            async.resolve(parsed)
        .fail (err)->
          async.reject(err)
      async.promise()

    getPhotos:(album_id)->
      async = $.Deferred()
      @getFB()
        .done (FB)->
          FB.api "#{album_id}/photos", (r)->
            async.resolve r.data
        .fail (err)->
          async.reject(err)
      async.promise()

if (typeof define is 'function') and (typeof define.amd is 'object') and define.amd
  define ["jquery","underscore"],($, _)-> FBApi($,_)
else
  window.FBApi = FBApi($,_)
