# Xtream Codes API Documentation

## Overview
The Xtream Codes API provides endpoints for IPTV clients to retrieve server information, live streams, video-on-demand (VOD) content, series, and Electronic Program Guide (EPG) data. 

## Base Endpoints & Authentication
All API requests require user authentication via query parameters. 

**Base Paths:**
- JSON API: `/player_api.php`
- XMLTV (EPG): `/xmltv.php`
- M3U Playlist: `/get.php`

**Authentication Parameters:**
All requests to `player_api.php` must include the following query parameters:
- `username` (string): Your account username.
- `password` (string): Your account password.

---

## 1. General & Account Information

### Get Server and User Info
Retrieves general server details and the status of the current user account.
- **Endpoint:** `/player_api.php`
- **Method:** `GET`
- **Query Parameters:** `username`, `password`
- **Response:**
  - `user_info`: User status, expiration date, active connections, allowed connections, trial status.
  - `server_info`: Server URL, port, timezone, RTMP port, and protocol.

---

## 2. Live TV (IPTV)

### Get Live Categories
Retrieves all available Live TV categories.
- **Endpoint:** `/player_api.php?action=get_live_categories`
- **Method:** `GET`
- **Response:** A list of category objects (`category_id`, `category_name`, `parent_id`).

### Get Live Streams
Retrieves all live TV channels. You can filter by category.
- **Endpoint:** `/player_api.php?action=get_live_streams`
- **Method:** `GET`
- **Optional Query Parameter:** `category_id` (Returns streams only for the specified category).
- **Response:** List of `LiveStreamItem` objects containing:
  - `stream_id` (int)
  - `name` (string)
  - `stream_type` (string - typically "live")
  - `stream_icon` (string - URL)
  - `epg_channel_id` (string)
  - `category_id` (int)
  - `tv_archive` (int - indicates if catchup is available)
  - `tv_archive_duration` (int - catchup duration in days)

---

## 3. Video On Demand (VOD / Movies)

### Get VOD Categories
Retrieves all available VOD categories.
- **Endpoint:** `/player_api.php?action=get_vod_categories`
- **Method:** `GET`
- **Response:** List of VOD category objects.

### Get VOD Streams
Retrieves all movies/VODs. You can filter by category.
- **Endpoint:** `/player_api.php?action=get_vod_streams`
- **Method:** `GET`
- **Optional Query Parameter:** `category_id`
- **Response:** List of `VodItem` objects containing:
  - `stream_id` (int)
  - `name` (string)
  - `stream_icon` (string)
  - `container_extension` (string - e.g., mp4, mkv)
  - `rating` (double)
  - `added` (timestamp)

### Get VOD Info
Retrieves detailed metadata for a specific VOD (IMDb data, actors, director, plot, media info).
- **Endpoint:** `/player_api.php?action=get_vod_info`
- **Method:** `GET`
- **Required Query Parameter:** `vod_id` (The `stream_id` of the movie)
- **Response:** - `info`: Extensive metadata (plot, cast, director, genre, release date, runtime, cover image).
  - `movie_data`: Container extension and stream details.

---

## 4. TV Series

### Get Series Categories
Retrieves all available TV Series categories.
- **Endpoint:** `/player_api.php?action=get_series_categories`
- **Method:** `GET`
- **Response:** List of Series category objects.

### Get Series
Retrieves the list of available series.
- **Endpoint:** `/player_api.php?action=get_series`
- **Method:** `GET`
- **Optional Query Parameter:** `category_id`
- **Response:** List of `SeriesItem` objects containing:
  - `series_id` (int)
  - `name` (string)
  - `cover` (string - URL)
  - `plot` (string)
  - `cast`, `director`, `genre`, `releaseDate`, `rating`
  - `category_id` (int)

### Get Series Info
Retrieves metadata for a series, along with a list of seasons and episodes.
- **Endpoint:** `/player_api.php?action=get_series_info`
- **Method:** `GET`
- **Required Query Parameter:** `series_id`
- **Response:**
  - `info`: Detailed series metadata.
  - `episodes`: A map/dictionary of episodes categorized by season number.
  - `seasons`: Array of season objects detailing cover images and episode counts.

---

## 5. Electronic Program Guide (EPG)

### Get Complete XMLTV (Full EPG)
Downloads the entire EPG for all channels in XMLTV format. 
- **Endpoint:** `/xmltv.php`
- **Method:** `GET`
- **Query Parameters:** `username`, `password`
- **Response:** XML file containing full programming data.

### Get Short EPG (Channel Specific)
Retrieves the timeline of programs for a specific live channel.
- **Endpoint:** `/player_api.php?action=get_short_epg`
- **Method:** `GET`
- **Required Query Parameters:** - `stream_id`: The ID of the live TV stream.
  - `limit`: (Optional) Number of listings to retrieve (e.g., 10).
- **Response:** List of `EpgListing` objects containing `start`, `end`, `title`, and `description`.

---

## 6. Playback & Streaming URLs

Though not standard REST JSON API endpoints, playback is achieved by constructing specific URLs based on the retrieved `stream_id` and `container_extension`.

**Live TV Playback:**
```text
http://{server_url}:{port}/{username}/{password}/{stream_id}
```
*(Optionally append `.m3u8` or `.ts` depending on the required stream format).*

**VOD (Movie) Playback:**
```text
http://{server_url}:{port}/movie/{username}/{password}/{stream_id}.{container_extension}
```

**Series (Episode) Playback:**
```text
http://{server_url}:{port}/series/{username}/{password}/{episode_stream_id}.{container_extension}
```

---

## Error Handling
The Xtream Codes API typically handles errors in two ways depending on the server configuration:
1. **HTTP Status Codes:** `401 Unauthorized` or `403 Forbidden` if authentication fails or an account is expired.
2. **Empty Bodies / Null Returns:** In case an `action` is invalid or empty datasets are queried, the server might return an empty JSON object `{}` or `null` rather than a standard HTTP error. (The `xtream_code_client` handles this gracefully via lenient parsing modes).