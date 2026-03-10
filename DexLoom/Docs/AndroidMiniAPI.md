# AndroidMini API - DexLoom Framework Stubs

## Overview

DexLoom reimplements **450+ Android/Java/third-party classes** as native C functions.
When guest bytecode calls an API method, the interpreter dispatches to these C implementations
instead of actual framework code. Classes span the Android SDK, Java standard library,
Kotlin stdlib, and popular third-party libraries.

## Class Categories

### android.app

- **Activity**: Full lifecycle (onCreate through onDestroy), setContentView, findViewById, startActivity/startActivityForResult, finish, onBackPressed, onSaveInstanceState/onRestoreInstanceState, recreate(), onCreateOptionsMenu/onOptionsItemSelected, onActivityResult, getIntent, setResult, getWindow
- **Fragment**: onCreateView, onViewCreated, onStart, onResume, onPause, onStop, onDestroyView lifecycle; getView, getActivity, getArguments, requireContext
- **Service**: startService -> onCreate -> onStartCommand; stopSelf, onBind, onDestroy; startForeground
- **IntentService**: Extends Service with onHandleIntent
- **Application**: onCreate, getApplicationContext, getPackageName
- **AlertDialog**: Builder pattern with setTitle, setMessage, setView, setPositiveButton, setNegativeButton, setNeutralButton, setCancelable, create, show
- **NotificationManager**: notify, cancel, createNotificationChannel
- **Notification.Builder**: setContentTitle, setContentText, setSmallIcon, build
- **PendingIntent**: getActivity, getBroadcast, getService

### android.content

- **Context**: getResources, getString, getSystemService (10+ services), checkSelfPermission, requestPermissions, getApplicationInfo, getClassLoader, bindService, openFileInput, openFileOutput, getExternalFilesDir, getFilesDir, getCacheDir, getPackageName, getAssets, getSharedPreferences, startActivity, startService, sendBroadcast, registerReceiver, unregisterReceiver
- **Intent**: Constructor with action/class, putExtra/getExtra for all types (String, int, long, boolean, float, double, Serializable, Parcelable, Bundle), setAction, setData, getAction, getData, getComponent, setFlags, addFlags, setClassName
- **BroadcastReceiver**: onReceive, registerReceiver/sendBroadcast with Intent action dispatch
- **ContentProvider**: onCreate, query, insert, update, delete, getType
- **ContentResolver**: query, insert, update, delete, openInputStream
- **SharedPreferences**: getString, getInt, getBoolean, getFloat, getLong, getStringSet, contains, getAll, edit; Editor with putString, putInt, putBoolean, putFloat, putLong, putStringSet, remove, clear, commit, apply
- **ClipboardManager**: setPrimaryClip, getPrimaryClip, hasPrimaryClip
- **ComponentName**: getClassName, getPackageName

### android.content.res

- **Resources**: getString, getLayout, getDimension, getDrawable, getColor, getStringArray, getIntArray, getQuantityString, getConfiguration, getDisplayMetrics
- **AssetManager**: open() extracts files from APK; returns InputStream with real read/available/close
- **Configuration**: orientation, screenWidthDp, screenHeightDp, locale, densityDpi
- **TypedArray**: Real backing data; getString, getInt, getBoolean, getDimension, getColor, getDrawable, getResourceId, recycle

### android.widget (30+ view types)

**Text**:
- **TextView**: setText, getText, setTextColor, setTextSize, setTypeface, setGravity, setLines, setMaxLines, setEllipsize, append, getLineCount
- **EditText**: getText (Editable), setText, setHint, setInputType, addTextChangedListener, SwiftUI TextField binding
- **AutoCompleteTextView**: setAdapter, setThreshold

**Buttons**:
- **Button**: Inherits TextView; onClick support
- **ImageButton**: setImageResource, setImageDrawable
- **ToggleButton**: setTextOn, setTextOff, isChecked, setChecked
- **FloatingActionButton**: Rendered as circular button with shadow

**Compound**:
- **CheckBox**: isChecked, setChecked, toggle, setOnCheckedChangeListener
- **Switch**: isChecked, setChecked, toggle, setOnCheckedChangeListener
- **RadioButton**: isChecked, setChecked
- **RadioGroup**: check, getCheckedRadioButtonId, setOnCheckedChangeListener, clearCheck

**Lists**:
- **RecyclerView**: Full adapter pattern with getItemCount, onCreateViewHolder, onBindViewHolder; ViewHolder with itemView; LinearLayoutManager, GridLayoutManager
- **ListView**: setAdapter, ArrayAdapter/BaseAdapter with getCount, getView, getItem
- **GridView**: setAdapter, setNumColumns
- **Spinner**: setAdapter, setOnItemSelectedListener, setSelection

**Input**:
- **SeekBar**: setProgress, setMax, setOnSeekBarChangeListener
- **RatingBar**: setRating, setNumStars, setOnRatingBarChangeListener
- **SearchView**: setOnQueryTextListener, setQuery, setIconified

**Display**:
- **ImageView**: setImageResource, setImageDrawable, setImageBitmap, setScaleType; real PNG/JPEG loading from APK
- **ProgressBar**: setProgress, setMax, setIndeterminate
- **WebView**: loadUrl, loadData, loadDataWithBaseURL; mapped to WKWebView bridge

**Layout**:
- **LinearLayout**: orientation (VStack/HStack), weightSum, gravity
- **RelativeLayout**: Parent alignment flags, centering
- **FrameLayout**: ZStack mapping
- **ConstraintLayout**: Basic solver with 12 constraint attributes, bias, parent+sibling anchoring
- **ScrollView / NestedScrollView**: SwiftUI ScrollView mapping
- **CoordinatorLayout**: ZStack with AppBarLayout support
- **SwipeRefreshLayout**: Pull-to-refresh with setOnRefreshListener, setRefreshing

**Navigation**:
- **TabLayout**: Tab management, addTab, setOnTabSelectedListener
- **ViewPager**: setAdapter, setCurrentItem
- **BottomNavigationView**: setOnNavigationItemSelectedListener
- **Toolbar**: setTitle, setNavigationOnClickListener
- **DrawerLayout**: openDrawer, closeDrawer

**Material**:
- **Chip / ChipGroup**: Rendered with chip styling
- **CardView**: Rounded corners, elevation/shadow
- **Snackbar**: make, show, setAction
- **TextInputLayout**: Hint and error display
- **AppBarLayout / CollapsingToolbarLayout**: Stub with title support

### android.view

- **View**: setOnClickListener (all view types), setOnLongClickListener, setVisibility, getId, setTag/getTag, setPadding, setBackground, setBackgroundColor, invalidate, requestLayout, getWidth, getHeight, getParent, animate (returns ViewPropertyAnimator)
- **ViewGroup**: addView, removeView, removeAllViews, getChildCount, getChildAt, indexOfChild
- **LayoutInflater**: inflate() parses binary XML layouts; from(Context)
- **Menu / MenuItem / SubMenu / MenuInflater**: Full menu system with add, findItem, setTitle, setIcon, setOnMenuItemClickListener
- **MotionEvent**: Touch event dispatch with getAction, getX, getY, ACTION_DOWN/UP/MOVE
- **Window**: setStatusBarColor, setNavigationBarColor, getDecorView
- **InputMethodManager**: hideSoftInputFromWindow, showSoftInput
- **GestureDetector**: onDown, onFling, onScroll, onLongPress

### android.os

- **Bundle**: Full get/put for all types (String, int, long, boolean, float, double, Serializable, Parcelable, CharSequence, StringArrayList, IntegerArrayList), containsKey, keySet, size, isEmpty, clear, putAll
- **Handler / Looper**: post, postDelayed (synchronous execution); Looper.getMainLooper, Looper.myLooper, Looper.prepare, Looper.loop; MessageQueue.addIdleHandler
- **HandlerThread**: start, getLooper, quit, quitSafely
- **Build / VERSION**: SDK_INT=33, RELEASE="13", MANUFACTURER, MODEL, DEVICE, BRAND, PRODUCT, BOARD, HARDWARE, FINGERPRINT
- **Environment**: getExternalStorageDirectory, getDataDirectory, getExternalStorageState, isExternalStorageEmulated
- **Process**: myPid, myUid, myTid
- **PowerManager**: isInteractive, isDeviceIdleMode; WakeLock acquire/release
- **Vibrator**: vibrate, cancel, hasVibrator
- **SystemClock**: uptimeMillis, elapsedRealtime

### android.net

- **Uri**: parse, toString, getScheme, getHost, getPath, getQueryParameter, getLastPathSegment, buildUpon; Uri.Builder
- **ConnectivityManager**: getActiveNetworkInfo, isActiveNetworkMetered
- **NetworkInfo**: isConnected, getType, getTypeName, getState

### android.database

- **SQLiteDatabase**: insert, update, delete, rawQuery, query, execSQL, beginTransaction, endTransaction, setTransactionSuccessful, isOpen, close
- **Cursor**: moveToFirst, moveToNext, moveToPosition, getCount, getColumnIndex, getString, getInt, getLong, getDouble, isAfterLast, close
- **ContentValues**: Field-backed 16-pair storage with put/get for all types, size, containsKey, keySet

### android.webkit

- **WebView**: loadUrl, loadData, loadDataWithBaseURL, goBack, canGoBack, setWebViewClient, setWebChromeClient, getSettings; mapped to WKWebView bridge
- **WebSettings**: setJavaScriptEnabled, setDomStorageEnabled, setCacheMode, setUserAgentString, setBuiltInZoomControls, setLoadWithOverviewMode, setUseWideViewPort, and 6 more
- **WebViewClient**: onPageStarted, onPageFinished, shouldOverrideUrlLoading
- **WebChromeClient**: onProgressChanged, onReceivedTitle

### android.media

- **MediaPlayer**: create, setDataSource, prepare, prepareAsync, start, pause, stop, release, reset, seekTo, setVolume, setLooping, setOnPreparedListener, setOnCompletionListener, setOnErrorListener, getDuration, getCurrentPosition, isPlaying, and more (25 methods total)
- **SoundPool**: load, play, pause, resume, stop, release
- **AudioAttributes / AudioAttributes.Builder**: setUsage, setContentType, build
- **AudioManager**: getStreamVolume, getStreamMaxVolume, setStreamVolume, requestAudioFocus, abandonAudioFocus; 16 stream/focus constants
- **AudioFocusRequest / AudioFocusRequest.Builder**: setOnAudioFocusChangeListener, build
- **Ringtone / RingtoneManager**: play, stop, isPlaying, getDefaultUri, getRingtone
- **AudioFormat / AudioFormat.Builder**: channel masks, encoding, sample rate

### android.location

- **LocationManager**: getLastKnownLocation, requestLocationUpdates, removeUpdates, isProviderEnabled, getBestProvider
- **Location**: Field-backed latitude/longitude/altitude/accuracy/speed; distanceTo, bearingTo
- **Criteria**: setAccuracy, setPowerRequirement
- **LocationListener**: onLocationChanged, onProviderEnabled, onProviderDisabled

### android.graphics

- **Canvas**: drawRect, drawCircle, drawLine, drawText, drawBitmap, drawColor, drawPath, drawArc, drawOval, drawRoundRect, save, restore, translate, rotate, scale, clipRect
- **Paint**: setColor, setStyle, setStrokeWidth, setTextSize, setTypeface, setAntiAlias, setAlpha, measureText
- **Bitmap**: createBitmap, getWidth, getHeight, getPixel, setPixel, recycle, compress
- **BitmapFactory**: decodeResource, decodeStream, decodeByteArray, decodeFile; BitmapFactory.Options (inSampleSize, inJustDecodeBounds, outWidth, outHeight)
- **Typeface**: create, createFromAsset, DEFAULT, BOLD, ITALIC, BOLD_ITALIC, MONOSPACE, SANS_SERIF, SERIF
- **Color**: parseColor, rgb, argb, valueOf, RED, GREEN, BLUE, BLACK, WHITE, TRANSPARENT
- **Rect / RectF**: set, contains, intersect, union, width, height
- **Point / PointF**: set, x, y
- **Path**: moveTo, lineTo, quadTo, cubicTo, close, addRect, addCircle, addArc
- **Matrix**: setTranslate, setScale, setRotate, postTranslate, postScale, postRotate
- **PorterDuff / PorterDuffXfermode**: Blend mode constants
- **Shader / LinearGradient / RadialGradient**: Stub constructors

### android.animation

- **ValueAnimator**: ofInt, ofFloat, setDuration, setRepeatCount, setRepeatMode, setInterpolator, addUpdateListener, start, cancel
- **ObjectAnimator**: ofFloat, ofInt, setTarget, setPropertyName, setDuration, start, cancel
- **AnimatorSet**: playTogether, playSequentially, setDuration, start, cancel
- **PropertyValuesHolder**: ofFloat, ofInt, setPropertyName
- **ViewPropertyAnimator**: alpha, translationX, translationY, scaleX, scaleY, rotation, setDuration, setInterpolator, start, withEndAction

### android.view.animation

- **Animation**: setDuration, setFillAfter, setRepeatCount, setInterpolator, setAnimationListener
- **AlphaAnimation**: fromAlpha, toAlpha
- **TranslateAnimation**: fromX/toX/fromY/toY
- **ScaleAnimation**: fromX/toX/fromY/toY with pivot
- **RotateAnimation**: fromDegrees, toDegrees with pivot
- **AnimationSet**: addAnimation, setFillAfter
- **AnimationUtils**: loadAnimation
- **Interpolators**: AccelerateInterpolator, DecelerateInterpolator, AccelerateDecelerateInterpolator, LinearInterpolator, OvershootInterpolator, BounceInterpolator

### android.util

- **Log**: d, i, w, e, v with tag+message logging; isLoggable
- **Pair**: Field-backed first/second, create() factory
- **TypedValue**: applyDimension, complexToDimensionPixelSize; COMPLEX_UNIT_* constants
- **SparseArray / SparseBooleanArray / SparseIntArray**: get, put, remove, size, keyAt, valueAt
- **DisplayMetrics**: widthPixels, heightPixels, density, densityDpi, scaledDensity

### android.text

- **TextUtils**: isEmpty, equals, join, isDigitsOnly, htmlEncode, getTrimmedLength, concat
- **TextWatcher**: beforeTextChanged, onTextChanged, afterTextChanged
- **Editable**: getText, toString, replace, insert, delete, append
- **SpannableString / SpannableStringBuilder**: Stub with toString
- **Html**: fromHtml

### android.preference

- **PreferenceManager**: getDefaultSharedPreferences

### android.content.pm

- **PackageManager**: PERMISSION_GRANTED, PERMISSION_DENIED constants; getPackageInfo, getApplicationInfo
- **PackageInfo / ApplicationInfo**: Field-backed metadata

### android.Manifest

- **Manifest.permission**: 16 common permission string constants (INTERNET, CAMERA, ACCESS_FINE_LOCATION, READ_EXTERNAL_STORAGE, etc.)

---

## AndroidX / Jetpack

### androidx.lifecycle

- **LiveData / MutableLiveData**: observe with lifecycle-aware callbacks, setValue notifies all observers, getValue, hasObservers, hasActiveObservers
- **ViewModel**: onCleared; subclasses store application state
- **ViewModelProvider**: get() instantiates ViewModel subclass via Class.newInstance and caches

### androidx.fragment

- **Fragment**: Full lifecycle (onAttach, onCreate, onCreateView, onViewCreated, onStart, onResume, onPause, onStop, onDestroyView, onDestroy, onDetach); getView, getActivity, getContext, requireContext, getArguments, setArguments, getChildFragmentManager

### androidx.navigation

- **NavController**: navigate (by ID or action), popBackStack, getCurrentDestination
- **NavHostFragment**: findNavController

### androidx.room

- **RoomDatabase**: Room.databaseBuilder, build, getOpenHelper
- **Room**: databaseBuilder factory
- **17 annotation stubs**: @Entity, @Dao, @Database, @Query, @Insert, @Update, @Delete, @PrimaryKey, @ColumnInfo, @Ignore, @ForeignKey, @Index, @Embedded, @Relation, @Transaction, @TypeConverter, @TypeConverters

### androidx.appcompat

- **AppCompatActivity**: Extends Activity with ActionBar support
- **ActionBar**: setTitle, setDisplayHomeAsUpEnabled, setHomeButtonEnabled

### androidx.recyclerview

- **RecyclerView**: Full adapter pattern with ViewHolder
- **RecyclerView.Adapter**: onCreateViewHolder, onBindViewHolder, getItemCount, notifyDataSetChanged
- **RecyclerView.ViewHolder**: itemView
- **LinearLayoutManager / GridLayoutManager**: Orientation, span count

---

## Java Standard Library

### java.lang

- **Object**: equals, hashCode, toString, getClass (returns Class object), clone, notify, notifyAll, wait
- **String**: 35+ methods -- substring, indexOf, lastIndexOf, replace, replaceAll, replaceFirst, split, trim, toLowerCase, toUpperCase, format, valueOf, join, getBytes, intern, matches, equalsIgnoreCase, codePointAt, codePointCount, startsWith, endsWith, contains, isEmpty, length, charAt, toCharArray, compareTo, compareToIgnoreCase, concat, String.format
- **StringBuilder / StringBuffer**: append (all types), toString, insert, delete, replace, reverse, length, charAt, setCharAt, indexOf
- **Class**: forName, getName, getSimpleName, isInterface, isArray, getSuperclass, getAnnotation, isAnnotationPresent, getAnnotations, getDeclaredMethods, getDeclaredFields, getDeclaredConstructors, getConstructor, newInstance, isAssignableFrom, isPrimitive, getClassLoader, getPackage
- **Thread**: currentThread, start (cooperative/synchronous), getName, setName, sleep, isAlive, interrupt, isInterrupted, getId, setPriority, setDaemon
- **Enum**: name, ordinal, compareTo, values, valueOf, toString
- **System**: arraycopy (real), currentTimeMillis (real), nanoTime, exit, gc, getProperty, setProperty, identityHashCode, lineSeparator, getenv
- **Math**: abs, max, min, sqrt, pow, ceil, floor, round, random, sin, cos, tan, atan2, log, exp, toRadians, toDegrees, PI, E, signum
- **Integer**: valueOf, parseInt, intValue, toString, toHexString, toBinaryString, toOctalString, compareTo, compare, MAX_VALUE, MIN_VALUE, TYPE, bitCount, highestOneBit, numberOfLeadingZeros, reverse
- **Long**: valueOf, parseLong, longValue, toString, toHexString, compareTo, compare, MAX_VALUE, MIN_VALUE
- **Float**: valueOf, parseFloat, floatValue, isNaN, isInfinite, intBitsToFloat, floatToIntBits, toString, compareTo, MAX_VALUE, MIN_VALUE, NaN, POSITIVE_INFINITY, NEGATIVE_INFINITY
- **Double**: valueOf, parseDouble, doubleValue, isNaN, isInfinite, longBitsToDouble, doubleToLongBits, toString, compareTo, MAX_VALUE, MIN_VALUE, NaN
- **Boolean**: valueOf, parseBoolean, booleanValue, toString, TRUE, FALSE
- **Byte**: valueOf, parseByte, byteValue, toString, MAX_VALUE, MIN_VALUE
- **Short**: valueOf, parseShort, shortValue, toString, MAX_VALUE, MIN_VALUE
- **Character**: valueOf, charValue, isDigit, isLetter, isLetterOrDigit, isWhitespace, isUpperCase, isLowerCase, toUpperCase, toLowerCase, toString, MIN_VALUE, MAX_VALUE
- **Number**: intValue, longValue, floatValue, doubleValue (abstract base)
- **Throwable**: getMessage, toString, getCause, printStackTrace, getStackTrace, setStackTrace
- **Exception / RuntimeException**: Standard hierarchy
- **NullPointerException / ClassCastException / IllegalArgumentException / IllegalStateException / UnsupportedOperationException / IndexOutOfBoundsException / ArrayIndexOutOfBoundsException / ArithmeticException / NumberFormatException / ClassNotFoundException / SecurityException / StackOverflowError / OutOfMemoryError / NoSuchMethodException / NoSuchFieldException**: All concrete exception types with constructors
- **Comparable / Iterable / AutoCloseable / Cloneable / Runnable / Callable**: Core interfaces

### java.lang.reflect

- **Method**: invoke with real dispatch, getName, getParameterTypes, getReturnType, getModifiers, getAnnotation, isAnnotationPresent, setAccessible
- **Field**: get/set with real field access, getName, getType, getModifiers, setAccessible, getAnnotation
- **Constructor**: newInstance, getName, getParameterTypes, getModifiers, setAccessible
- **Proxy**: newProxyInstance with InvocationHandler dispatch; runtime DxClass generation
- **Array**: newInstance, get, set, getLength
- **Modifier**: isPublic, isPrivate, isProtected, isStatic, isFinal, isAbstract, isInterface

### java.util

- **ArrayList**: Full implementation with real Iterator (hasNext/next for for-each loops), add, addAll, remove, get, set, size, isEmpty, clear, contains, indexOf, lastIndexOf, toArray, subList, sort, Collections.sort
- **HashMap**: get, put, remove, containsKey, containsValue, putAll, getOrDefault, putIfAbsent, size, isEmpty, clear, toString; keySet/values/entrySet return iterable collections with real Iterator
- **LinkedHashMap**: Extends HashMap with insertion-order iteration
- **TreeMap**: Sorted map with comparator support; firstKey, lastKey, headMap, tailMap, subMap
- **HashSet**: add, remove, contains, size, isEmpty, clear, iterator
- **TreeSet**: Sorted set with comparator support; first, last, headSet, tailSet, subSet
- **LinkedHashSet**: Insertion-order set
- **LinkedList**: Full List+Deque implementation; addFirst, addLast, getFirst, getLast, removeFirst, removeLast
- **Stack**: push, pop, peek, isEmpty, search
- **ArrayDeque**: addFirst, addLast, pollFirst, pollLast, peekFirst, peekLast
- **PriorityQueue**: add, poll, peek, size, comparator
- **Collections**: emptyList, emptyMap, emptySet, singleton, singletonList, singletonMap, addAll, sort, unmodifiableList, unmodifiableMap, synchronizedList, synchronizedMap, reverse, shuffle, frequency, disjoint, min, max
- **Arrays**: asList, copyOf, copyOfRange, fill, equals, deepEquals, sort, binarySearch, toString, deepToString, stream
- **Objects**: equals, hashCode, hash, requireNonNull, toString, isNull, nonNull, compare
- **Optional**: of, ofNullable, empty, isPresent, get, orElse, orElseGet, orElseThrow, ifPresent, map, flatMap, filter
- **Calendar**: getInstance, get, set, add, getTime, setTime, getTimeInMillis, DAY_OF_MONTH, MONTH, YEAR, HOUR_OF_DAY, MINUTE, SECOND
- **Date**: Constructor (millis), getTime, setTime, before, after, compareTo, toString
- **UUID**: randomUUID, fromString, toString, getLeastSignificantBits, getMostSignificantBits
- **Locale**: getDefault, getLanguage, getCountry, toString, ENGLISH, US, forLanguageTag
- **Random**: nextInt, nextLong, nextFloat, nextDouble, nextBoolean, nextBytes
- **Timer / TimerTask**: schedule, scheduleAtFixedRate, cancel (cooperative)
- **Formatter**: format, toString, close
- **StringTokenizer**: hasMoreTokens, nextToken, countTokens
- **Properties**: getProperty, setProperty, load, store
- **Map.Entry**: getKey, getValue, setValue (on HashMap/TreeMap entries)

### java.util.concurrent

- **ExecutorService**: submit, execute, shutdown, shutdownNow, isShutdown, isTerminated (cooperative)
- **ThreadPoolExecutor**: Core/max pool size, keep-alive, work queue
- **ScheduledExecutorService**: schedule, scheduleAtFixedRate, scheduleWithFixedDelay
- **Future**: get, isDone, isCancelled, cancel (returns immediately)
- **CompletableFuture**: thenApply, thenAccept, thenCompose, thenRun, supplyAsync, runAsync, whenComplete, exceptionally, join, complete
- **AtomicInteger**: get, set, getAndIncrement, incrementAndGet, getAndDecrement, decrementAndGet, compareAndSet, addAndGet, getAndAdd
- **AtomicBoolean**: get, set, compareAndSet, getAndSet
- **AtomicReference**: get, set, compareAndSet, getAndSet
- **AtomicLong**: get, set, incrementAndGet, decrementAndGet, addAndGet, compareAndSet
- **ConcurrentHashMap**: Full Map interface; putIfAbsent, computeIfAbsent
- **CopyOnWriteArrayList / CopyOnWriteArraySet**: Thread-safe collections
- **ReentrantLock**: lock, unlock, tryLock, isLocked
- **CountDownLatch**: countDown, await, getCount
- **Semaphore**: acquire, release, tryAcquire, availablePermits
- **LinkedBlockingQueue / ArrayBlockingQueue / PriorityBlockingQueue**: put, take, offer, poll, size
- **ConcurrentLinkedQueue / ConcurrentLinkedDeque**: Concurrent queue/deque operations
- **Executors**: newSingleThreadExecutor, newFixedThreadPool, newCachedThreadPool, newScheduledThreadPool

### java.io

- **File**: Constructor (String), Constructor (File, String), exists, isDirectory, isFile, getName, getPath, getAbsolutePath, length, delete, mkdir, mkdirs, listFiles, list, createTempFile, canRead, canWrite, lastModified, renameTo, getParent, getParentFile
- **InputStream / OutputStream**: read, write, close, available, flush; real byte buffer backing for asset streams
- **FileInputStream / FileOutputStream**: File-backed streams with read/write/close
- **BufferedReader / BufferedWriter**: readLine, read, write, close, newLine, flush
- **InputStreamReader / OutputStreamWriter**: Character stream wrappers
- **PrintWriter / PrintStream**: print, println, printf, format, flush, close
- **ByteArrayInputStream / ByteArrayOutputStream**: In-memory byte streams; toByteArray
- **DataInputStream / DataOutputStream**: readInt, readLong, readUTF, writeInt, writeLong, writeUTF
- **Closeable / Flushable**: Core interfaces

### java.nio

- **ByteBuffer**: Field-backed storage with position/limit/capacity; allocate, allocateDirect, wrap, get, put, getInt, putInt, getLong, putLong, getFloat, putFloat, getDouble, putDouble, getShort, putShort, flip, rewind, clear, remaining, hasRemaining, order, array, arrayOffset, slice, duplicate
- **ByteOrder**: BIG_ENDIAN, LITTLE_ENDIAN, nativeOrder
- **Charset / StandardCharsets**: UTF_8, US_ASCII, ISO_8859_1; forName, name
- **FileChannel**: Stub with size, position, read, write

### java.lang.ref

- **WeakReference**: get, clear, enqueue; extends Reference
- **SoftReference**: get, clear, enqueue; extends Reference
- **PhantomReference**: Stub
- **ReferenceQueue**: Stub with poll

### java.net

- **URL**: Constructor (String), toString, openConnection, getProtocol, getHost, getPort, getPath, getFile
- **URI**: create, toString, getScheme, getHost, getPort, getPath
- **HttpURLConnection**: Real URLSession bridge -- setRequestMethod (GET/POST/PUT/DELETE), setRequestProperty, getResponseCode, getInputStream (real response body), getOutputStream, getHeaderField, connect, disconnect, setDoOutput, setDoInput, setConnectTimeout, setReadTimeout
- **HttpsURLConnection**: Extends HttpURLConnection + setSSLSocketFactory, setHostnameVerifier

### java.lang.annotation

- **Annotation**: annotationType
- **Retention / RetentionPolicy**: SOURCE, CLASS, RUNTIME
- **Target / ElementType**: TYPE, FIELD, METHOD, PARAMETER, CONSTRUCTOR, etc.

### java.math

- **BigDecimal**: Stub with valueOf, toString, add, subtract, multiply, divide, compareTo
- **BigInteger**: Stub with valueOf, toString, add, subtract, multiply, compareTo

---

## Third-Party Libraries

### RxJava3 (11 classes, 85 methods)

- **Observable**: just, fromIterable, create, map, flatMap, filter, subscribeOn, observeOn, subscribe, zip, merge, concat, distinctUntilChanged, debounce, take, skip, toList, switchMap, doOnNext, doOnError, doOnComplete
- **Single**: just, create, map, flatMap, subscribeOn, observeOn, subscribe, zip, fromCallable
- **Completable**: create, complete, fromAction, andThen, subscribe, subscribeOn, observeOn
- **Maybe**: just, empty, create, map, flatMap, subscribe
- **Flowable**: just, fromIterable, create, map, flatMap, subscribe, onBackpressureBuffer
- **Disposable**: dispose, isDisposed
- **CompositeDisposable**: add, remove, clear, dispose, isDisposed
- **Schedulers**: io, computation, mainThread, newThread, single
- **DisposableObserver / DisposableSingleObserver**: onNext, onError, onComplete
- **PublishSubject / BehaviorSubject**: onNext, onError, onComplete, subscribe

### OkHttp3 (18 classes, 120 methods)

- **OkHttpClient**: newCall, newBuilder; OkHttpClient.Builder with connectTimeout, readTimeout, writeTimeout, addInterceptor, build
- **Request**: url, method, headers, body; Request.Builder with url, get, post, put, delete, patch, header, addHeader, build
- **Response**: code, message, body, headers, isSuccessful, close; Response.Builder
- **Call**: execute (real URLSession bridge), enqueue (async callback), cancel, isExecuted, isCanceled
- **Callback**: onFailure, onResponse
- **Interceptor / Interceptor.Chain**: proceed, request, connection
- **MediaType**: parse, type, subtype, charset
- **RequestBody**: create, contentType, contentLength; FormBody, MultipartBody stubs
- **ResponseBody**: string, bytes, byteStream, contentLength, contentType, close
- **Headers**: get, names, values, toMultimap; Headers.Builder
- **HttpUrl**: parse, toString, scheme, host, port, encodedPath, queryParameterNames, queryParameter; HttpUrl.Builder
- **Cache**: Stub constructor
- **ConnectionPool**: Stub constructor
- **Dispatcher**: Stub

### Retrofit2 (12 classes, 50 methods)

- **Retrofit**: create (dynamic proxy); Retrofit.Builder with baseUrl, client, addConverterFactory, addCallAdapterFactory, build
- **Call**: execute, enqueue, cancel, clone, request
- **Callback**: onResponse, onFailure
- **Response**: body, code, message, isSuccessful, errorBody, headers
- **Converter / Converter.Factory**: responseBodyConverter, requestBodyConverter
- **GsonConverterFactory**: create
- **RxJava3CallAdapterFactory**: create
- **HTTP annotations**: @GET, @POST, @PUT, @DELETE, @PATCH, @HEAD, @HTTP, @Path, @Query, @QueryMap, @Body, @Field, @FieldMap, @Header, @HeaderMap, @Url

### Glide (6 classes, 40 methods)

- **Glide**: with (Activity/Context/Fragment), get, init
- **RequestManager**: load (String/int/Uri), clear, pauseRequests, resumeRequests
- **RequestBuilder**: into (ImageView), placeholder, error, fallback, override, centerCrop, fitCenter, circleCrop, transform, transition, apply, submit
- **RequestOptions**: placeholder, error, override, centerCrop, fitCenter, circleCrop
- **Target**: onResourceReady, onLoadStarted, onLoadFailed, onLoadCleared
- **DrawableTransitionOptions**: withCrossFade

### Kotlin Coroutines (stubs)

- **CoroutineScope**: launch, async
- **Dispatchers**: Main, IO, Default
- **Job**: cancel, isActive, isCompleted
- **Deferred**: await

### Kotlin Standard Library (stubs)

- **kotlin.Unit**: INSTANCE
- **kotlin.Pair**: first, second
- **kotlin.Triple**: first, second, third
- **kotlin.collections**: listOf, mapOf, setOf, mutableListOf, mutableMapOf, mutableSetOf
- **kotlin.text**: Regex, MatchResult

---

## Utility Classes

- **android.util.Log**: d, i, w, e, v with tag+message logging to DexLoom log system
- **android.util.Pair**: Field-backed first/second, create() factory
- **android.widget.Toast**: makeText (logs message), show (no-op); LENGTH_SHORT, LENGTH_LONG
- **ClassLoader**: loadClass, getParent, getResource, getSystemClassLoader
- **java.util.logging.Logger**: getLogger, info, warning, severe, fine, finest
