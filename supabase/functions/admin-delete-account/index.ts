import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify admin role
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    const { data: { user } } = await supabaseClient.auth.getUser(token)

    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // Check if user is admin
    const { data: profile } = await supabaseClient
      .from('users_profile')
      .select('role')
      .eq('user_id', user.id)
      .single()

    if (profile?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Forbidden: Admin access required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    const { user_id } = await req.json()

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // Delete in order (respecting foreign key constraints)
    // 1. Delete language skills
    await supabaseClient
      .from('interpreter_language_skills')
      .delete()
      .eq('user_id', user_id)

    // 2. Delete skills
    await supabaseClient
      .from('interpreter_skills')
      .delete()
      .eq('user_id', user_id)

    // 3. Delete specializations
    await supabaseClient
      .from('interpreter_specializations')
      .delete()
      .eq('user_id', user_id)

    // 4. Delete languages
    await supabaseClient
      .from('interpreter_languages')
      .delete()
      .eq('user_id', user_id)

    // 5. Get and delete certificates (and their files from storage)
    const { data: certificates } = await supabaseClient
      .from('interpreter_certificates')
      .select('certificate_url')
      .eq('user_id', user_id)

    if (certificates && certificates.length > 0) {
      // Delete files from storage
      const filePaths = certificates
        .map(cert => cert.certificate_url?.replace(/^.*\/certificates\//, ''))
        .filter(Boolean)

      if (filePaths.length > 0) {
        await supabaseClient.storage
          .from('certificates')
          .remove(filePaths)
      }

      // Delete certificate records
      await supabaseClient
        .from('interpreter_certificates')
        .delete()
        .eq('user_id', user_id)
    }

    // 6. Delete interpreter details
    await supabaseClient
      .from('interpreter_details')
      .delete()
      .eq('user_id', user_id)

    // 7. Delete user profile
    await supabaseClient
      .from('users_profile')
      .delete()
      .eq('user_id', user_id)

    // 8. Delete auth user (this will cascade to other auth-related tables)
    const { error: authError } = await supabaseClient.auth.admin.deleteUser(user_id)
    
    if (authError) throw authError

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Account and all related data deleted successfully' 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
